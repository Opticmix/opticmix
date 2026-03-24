# OpticMix Tracker Improvement Specification

> **Purpose**: opticmix_tracker의 스켈레톤 추적 품질을 원본 TrackingSvc(LeapSvc.exe) 수준으로 끌어올리기 위한 명세서.
> 다른 에이전트에게 전달하여 구현을 위임하기 위한 문서.

---

## 1. 현재 상태 요약

opticmix_tracker는 Ultraleap AOT 모델을 독립 로드하여 핸드 트래킹을 수행하고,
OMTK 프로토콜(TCP 23456)로 결과를 서빙한다. LeapC API 호환 DLL(OpticMixC.dll)도 제공한다.

**작동은 하지만** 원본 대비 스켈레톤 정확도와 안정성이 현저히 떨어지는 상태.

### 문제 원인 3가지

| 레벨 | 문제 | 영향도 |
|------|------|--------|
| **전처리** | 렌즈 왜곡보정 누락, resize/crop 누락 | **Critical** — 모델 입력이 왜곡됨 |
| **후처리** | confidence 하드코딩, chirality 고정, bone roll 누락 등 | **High** — 출력 품질 저하 |
| **API** | LeapC stub 함수들이 빈 껍데기 | **Medium** — Control Panel 호환 불가 |

---

## 2. Phase 1: 전처리 파이프라인 복원 (Critical)

### 2.1 현재 코드 위치

- `tracker/src/main.cpp` — `preprocess_frame()` 함수 (line ~271-289)

### 2.2 현재 동작

```
raw 384x768 (row-interleaved) → 직접 deinterleave → NCHW [1,2,384,384] uint8
```

렌즈 왜곡보정 없음. resize 없음. crop 없음.

### 2.3 목표 동작 (원본 TrackingSvc 파이프라인 재현)

```
raw 384x768 (row-interleaved)
  → deinterleave: even rows → Left (384x384), odd rows → Right (384x384)
  → 각 eye를 vertical stack: Mat(768, 384) = [Left; Right]
  → resize(768x384 → 800x400)
  → Crop ROI: Left = (8, 8, 384, 384), Right = (8, 408, 384, 384)
  → LUT 기반 렌즈 왜곡보정 (per eye)
  → Write to NCHW [1, 2, 384, 384] uint8
```

### 2.4 렌즈 왜곡보정 (Undistortion) 구현

#### 캘리브레이션 데이터

`main.cpp`의 `REAL_CALIBRATION[71]`에 이미 값이 있음:

```
Camera 0:
  cx = -383.5, cy = -381.5
  focal_length = 243.7555
  distortion coefficients: [-0.8444782, 1.7302748, 1.0072310, 48.2147713, -10.6455450, ...]

Camera 1:
  cx = -383.5, cy = -383.5
  focal_length = 242.9238
  distortion coefficients: [3.3469751, -0.1693968, 1.0072310, 48.2147713, -10.6455450, ...]
```

#### 구현 방법

1. **시작 시 LUT 생성** (한 번만):
   - OpenCV `cv::initUndistortRectifyMap()` 또는 직접 LUT 계산
   - 캘리브레이션 71 float에서 카메라 매트릭스 + 왜곡 계수 추출
   - 384x384 크기의 remap LUT (x_map, y_map) 2개 생성 (cam0, cam1)

2. **매 프레임 적용**:
   - `cv::remap(src_eye, dst_eye, x_map, y_map, INTER_LINEAR)`
   - 또는 고속 정수 LUT로 직접 픽셀 재매핑 (GPU 없으므로 속도 중요)

#### 캘리브레이션 71-float 레이아웃 (RE 분석 기반)

```
[0]     = 0.0 (unused/padding)
[1]     = baseline (66.291mm)
[2]     = 0.5 (unused)

--- Camera 0 ---
[3]     = cx0 (-383.5)
[4]     = cy0 (-381.5)
[5]     = focal0 (243.7555)
[6..10] = distortion coefficients (5개, Brown-Conrady model)
[11..20]= rectification/undistortion LUT params (10개)
[21]    = map_scale (8.0)
[22..29]= reserved/identity matrix entries
[30]    = FLT_MAX sentinel (3.4028235e+38)

--- Camera 1 ---
[31..35]= distortion shift + focal1 (242.9238)
[36]    = cx1 (-383.5)
[37]    = cy1 (-383.5)
[38]    = focal1
[39..43]= distortion coefficients
[44..53]= rectification params
[54]    = map_scale (8.0)
[55..62]= reserved
[63]    = FLT_MAX sentinel
[64..70]= additional params
```

> **주의**: 이 레이아웃은 RE 추정이므로, 왜곡보정 적용 후 원본 LeapSvc와 비교 검증 필요.
> `--verify` 모드에서 custom vs reference 비교하면 정확도 차이 확인 가능.

#### 성능 목표

- LUT 생성: 시작 시 1회, 100ms 이내
- 매 프레임 remap: 384x384 × 2eye, **1ms 이내** (90fps 유지 필수)
- OpenCV remap이 너무 느리면 직접 정수 LUT + memcpy 최적화

### 2.5 resize + crop 복원

원본은 `resize(768x384 → 800x400)` 후 `crop(8,8,384,384)` per eye를 수행.
이는 렌즈 왜곡보정 결과의 경계 아티팩트를 제거하기 위한 것.

**구현**:
- deinterleave 후 vertical stack → `cv::resize(Mat(768,384), Mat(800,400))`
- left ROI = `Mat(800,400)(Rect(8, 8, 384, 384))`
- right ROI = `Mat(800,400)(Rect(8, 408, 384, 384))`
- 이 ROI에 undistortion LUT 적용
- → NCHW 버퍼에 복사

---

## 3. Phase 2: 후처리 개선 (High)

### 3.1 confidence 하드코딩 → 모델 값 사용

**파일**: `tracker/src/postprocessor.h` — `HandTracker::process_hand()` (line 519)

**현재**:
```cpp
out->confidence = 1.0f; // hardcoded 1.0 (RVA 0x1B87BF4)
```

**변경**:
```cpp
out->confidence = confidence; // 이미 line 491에서 hand92[h184::CONFIDENCE]로 읽음
```

### 3.2 chirality (좌/우 판별) — 모델 기반으로 변경

**현재** (line 518):
```cpp
out->type = (slot == 0) ? eHandType_Left : eHandType_Right;
```

**변경**:
```cpp
float chiral = hand92[h184::CHIRALITY];
out->type = (chiral < 0.5f) ? eHandType_Left : eHandType_Right;
```

> **주의**: 원본 LeapSvc에서 slot 0이 항상 LEFT인지, 아니면 chirality 값 기반인지 추가 검증 필요.
> `--verify` 모드에서 양손을 넣고 비교하여 확인.

### 3.3 bone rotation — roll 축 추가

**파일**: `tracker/src/postprocessor.h` — `compute_bone_rotation()` (line 226-252)

**현재 문제**: yaw/pitch만으로 quaternion 생성 → **roll(twist)이 누락**.
손가락이 비틀린 경우 렌더링이 부정확.

**해결 방법**: 인접 뼈의 방향과 손바닥 법선을 이용하여 roll 추정.

```
목표 rotation = align (0,0,1) → bone_direction, with up-hint from palm_normal
```

**구현**:
```cpp
static inline OM_QUATERNION compute_bone_rotation_v2(
    const OM_VECTOR& prev_joint, const OM_VECTOR& next_joint,
    const OM_VECTOR& palm_normal)  // up hint 추가
{
    OM_VECTOR fwd = vec3_normalize(vec3_sub(next_joint, prev_joint));
    if (vec3_length(fwd) < 1e-6f) return identity_quat();

    // Gram-Schmidt: right = normalize(fwd × up), up' = right × fwd
    OM_VECTOR right = vec3_normalize(vec3_cross(fwd, palm_normal));
    if (vec3_length(right) < 1e-6f) {
        // fwd parallel to palm_normal — fallback to current method
        return compute_bone_rotation(prev_joint, next_joint);
    }
    OM_VECTOR up = vec3_cross(right, fwd);

    // Rotation matrix columns: [right, up, fwd] → quaternion
    return matrix_to_quaternion(right, up, fwd);
}
```

`set_bone()` 호출 시 `palm.normal`을 전달하도록 시그니처 변경 필요.

> **TrackingSvc 원본 구현** (RVA 0xB1C810): 정확한 알고리즘은 `set_rotation_from_direction`인데,
> 인접 뼈의 이전 방향을 up-hint로 사용하는 방식. 위 palm_normal 기반은 근사치이며,
> 정확도가 부족하면 finger chain을 따라 이전 뼈 방향을 전파하는 방식으로 교체.

### 3.4 "Squishy Hands" 정규화

원본 LeapSvc의 `use_squishy_hands: true` 설정에 해당.
뼈 길이를 표준 비율로 정규화하여 손가락이 늘어나거나 줄어드는 현상 방지.

**구현 개요**:
1. 표준 뼈 길이 비율 테이블 (손가락별, 뼈별 — RE에서 추출 필요)
2. 매 프레임 실제 뼈 길이를 측정
3. 관절 위치를 표준 비율에 맞춰 재조정 (방향 유지, 길이만 스케일)

> **우선순위**: Phase 1, 3.1~3.3 해결 후 효과를 보고 진행 여부 결정.
> Squishy hands 없이도 충분한 품질이 나올 수 있음.

### 3.5 Hand ID 연속성 개선

**현재**: slot 기반 monotonic counter → 손이 잠시 사라졌다 나타나면 새 ID 부여.

**개선**: 이전 프레임 손 위치와 현재 프레임 손 위치의 거리 기반 매칭.
- 이전 손 위치와 50mm 이내면 같은 ID 유지
- 임계값 초과 시 새 ID 부여

---

## 4. Phase 3: OpticMixC.dll API 완성 (Medium)

### 4.1 현재 stub 상태

**파일**: `tracker/src/opticmixc.cpp`

| API | 현재 상태 | 필요 구현 |
|-----|----------|----------|
| `LeapCreateConnection` | ✅ 동작 | — |
| `LeapOpenConnection` | ✅ 동작 | — |
| `LeapPollConnection` | ✅ Tracking/Image 이벤트 | — |
| `LeapGetDeviceList` | ❌ `*pnArray = 0` | 디바이스 1개 보고 |
| `LeapOpenDevice` | ❌ dummy handle | 실제 핸들 반환 |
| `LeapGetDeviceInfo` | ❌ 빈 stub | serial, PID/VID, baseline 등 반환 |
| `LeapSetPolicyFlags` | ❌ 무시 | Images 정책 플래그 반영 |
| `LeapSetTrackingMode` | ❌ 무시 | tracker에 모드 전달 |
| `LeapGetTrackingMode` | ❌ 항상 0 | 현재 모드 반환 |
| `LeapSubscribeEvents` | ❌ 무시 | 이벤트 구독 처리 |

### 4.2 LeapGetDeviceList 구현

```cpp
LEAP_EXPORT eLeapRS __stdcall LeapGetDeviceList(
    LEAP_CONNECTION hConnection, LEAP_DEVICE_REF* pArray, uint32_t* pnArray)
{
    if (!pnArray) return eLeapRS_InvalidArgument;
    if (!pArray) {
        *pnArray = 1; // 디바이스 1개
        return eLeapRS_Success;
    }
    if (*pnArray >= 1) {
        pArray[0].handle = (void*)1;
        pArray[0].id = 1;
        *pnArray = 1;
    }
    return eLeapRS_Success;
}
```

### 4.3 LeapGetDeviceInfo 구현

```cpp
struct LEAP_DEVICE_INFO {
    uint32_t size;
    uint32_t status;         // 0x01 = streaming
    uint32_t caps;
    uint32_t pid;            // 0x1234
    uint32_t baseline;       // 66291 (µm)
    uint32_t serial_length;
    char*    serial;
    float    h_fov;
    float    v_fov;
    uint32_t range;
};

LEAP_EXPORT eLeapRS __stdcall LeapGetDeviceInfo(
    void* hDevice, LEAP_DEVICE_INFO* info)
{
    if (!info) return eLeapRS_InvalidArgument;

    static char serial[] = "OPTICMIX-001";
    info->size = sizeof(LEAP_DEVICE_INFO);
    info->status = 0x01;     // streaming
    info->caps = 0x01;       // hand tracking
    info->pid = 0x1214;      // SIR170 PID
    info->baseline = 66291;  // µm (66.291mm)
    info->serial_length = (uint32_t)strlen(serial) + 1;
    info->serial = serial;
    info->h_fov = 2.618f;    // ~150 degrees
    info->v_fov = 2.007f;    // ~115 degrees
    info->range = 600;       // mm
    return eLeapRS_Success;
}
```

### 4.4 LeapSetPolicyFlags — 이미지 정책 반영

현재 tracker 서버는 이미 이미지를 5프레임마다 broadcast하지만,
클라이언트가 `eLeapPolicyFlag_Images` (0x01)을 설정하지 않으면 보내지 않도록:

```cpp
LEAP_EXPORT eLeapRS __stdcall LeapSetPolicyFlags(
    LEAP_CONNECTION hConnection, uint64_t set, uint64_t clear)
{
    auto* cs = (ConnectionState*)hConnection;
    if (!cs) return eLeapRS_InvalidArgument;
    cs->policy_flags |= set;
    cs->policy_flags &= ~clear;
    return eLeapRS_Success;
}
```

`ConnectionState`에 `uint64_t policy_flags = 0;` 필드 추가.
`LeapPollConnection`에서 `has_image` 반환 시 `policy_flags & 0x01` 체크.

---

## 5. 파일 수정 범위

### 수정 대상 파일

| 파일 | 변경 내용 |
|------|----------|
| `tracker/src/main.cpp` | `preprocess_frame()` 재작성: resize + crop + undistortion LUT |
| `tracker/src/postprocessor.h` | confidence 모델값 사용, chirality 모델값, bone rotation v2, (squishy hands) |
| `tracker/src/opticmixc.cpp` | `LeapGetDeviceList`, `LeapGetDeviceInfo`, `LeapSetPolicyFlags` 구현 |
| `tracker/src/hand_types.h` | 변경 없음 (구조체는 이미 올바름) |
| `tracker/src/tracking_server.h` | 변경 없음 |

### 새로 추가할 파일 (필요 시)

| 파일 | 내용 |
|------|------|
| `tracker/src/undistortion.h` | LUT 생성 + remap 함수 (OpenCV 또는 직접 구현) |

---

## 6. 빌드 & 테스트

### 빌드

```bash
cd tracker
mkdir -p build && cd build
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release
```

의존성:
- OpenCV 4.10.0: `C:\opencv\opencv\build`
- MSVC 2022
- Winsock2 (ws2_32.lib)

### 테스트 방법

#### A. 단독 진단 (`--diag`)

```bash
opticmix_tracker.exe --model "C:\path\to\model.dll" --diag --verbose
```

합성 이미지로 모델 출력 확인. 스켈레톤 데이터 덤프.

#### B. 실시간 트래킹 (`--track`)

```bash
opticmix_tracker.exe --model "C:\path\to\model.dll" --track --host 192.168.55.31 --port 7100
```

스트리머에서 프레임 수신 → 모델 실행 → 콘솔에 손 위치 출력.

#### C. 원본 대비 검증 (`--verify`)

```bash
opticmix_tracker.exe --model "C:\path\to\model.dll" --verify --host 192.168.55.31 --port 7100
```

원본 LeapSvc(동시 실행)와 커스텀 tracker 출력을 프레임 단위 비교.
palm position 오차(mm), pinch distance 오차, grab 오차 등 출력.

#### D. 클라이언트 테스트

```bash
# tracker 서버 실행 (포트 23456)
opticmix_tracker.exe --model "..." --track --server-port 23456

# loopback 테스트 (OpticMixC.dll 경유)
loopback_test.exe
```

### 검증 기준

| 항목 | 목표 |
|------|------|
| Palm position 오차 | < 5mm (원본 대비) |
| Finger tip 오차 | < 10mm (원본 대비) |
| Pinch distance 오차 | < 5mm |
| FPS | >= 60fps (90fps 목표) |
| 연속 트래킹 | 5분 이상 ID 유지 |

---

## 7. 구현 순서 (권장)

```
Phase 1.1  confidence / chirality 수정 (5분 작업, 즉시 효과)
Phase 1.2  preprocess_frame() — undistortion LUT 구현 (핵심, 가장 큰 품질 개선)
Phase 1.3  preprocess_frame() — resize + crop 복원
Phase 2.1  bone rotation v2 (roll 축 추가)
Phase 2.2  LeapGetDeviceList / LeapGetDeviceInfo 구현
Phase 2.3  LeapSetPolicyFlags 이미지 정책 반영
Phase 3.1  Hand ID 연속성 개선
Phase 3.2  Squishy hands 정규화 (선택)
```

각 Phase 완료 후 `--verify` 모드로 원본 대비 오차 측정하여 진행 여부 판단.

---

## 8. 참고 자료

| 문서 | 위치 |
|------|------|
| 전체 파이프라인 분석 | `memory/tracking_pipeline_analysis.md` |
| 원본 DLL RE | `memory/deep_analysis_results.md` |
| 캘리브레이션 데이터 | `tracker/src/main.cpp` — `REAL_CALIBRATION[71]` |
| AOT 인터페이스 | `tracker/src/aot_interface.h` (9개 함수 포인터) |
| 네트워크 프로토콜 | `edge/protocol/net_protocol.h` |
| 스켈레톤 오프셋 해결 기록 | `memory/project_skeleton_fitting_todo.md` |
| 프레임 포맷 기록 | `memory/project_frame_format_and_tracking.md` |
| LeapC SDK 헤더 (참고) | Ultraleap SDK `include/LeapC.h` |
