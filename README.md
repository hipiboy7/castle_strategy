# castle_strategy — 캐슬 제패(가칭)

「캐슬」(웹툰) 비영리 개인용 팬게임이다. 캐슬의 조직 하나를 골라 사업 · 사람 · 구역을 키우고, 다른 조직과 싸워 캐슬을 차지하는 턴제 조직 경영 전략이다. Godot 4 · Android 세로.

- 원작 사실 · 공통 규칙 · 장르 팩은 옆 폴더 `../castle_common` 에서 받는다(읽기만 — `CLAUDE.md` 13절).
- 범위와 구조의 원천은 기획서 08 `../castle_common/docs/기획서/08_캐슬제패_조직경영전략.md` 다.

## 빠른 시작 (작업 서버 — 화면 없는 검증만)
- 엔진 받기: `python3 -B scripts/get_godot.py` — Godot 4.7.2 를 `.tools/` 에 받는다(멱등)
- 전체 검증: `python3 -B scripts/verify.py` — 마지막 줄이 `verify: N/M 통과 · X초 — OK` 이고 종료 코드가 0 이면 통과다
- 시나리오 A 자동 진행(화면 없음 · 모든 조직 AI): `.tools/godot/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -- --autoplay --turns 26 --seed 1` — `RESULT {…"hash":"b9259bb7a56b5bc3"…}` 한 줄(기준값은 `tests/integration/golden_a.json` — C3 에서 AI 습격이 들어가 바뀜)
- 전투 시험(화면 없음 · 실시간 구간 판을 봇으로 끝까지 — C4): `.tools/godot/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -- --fight-test --seed 1` — `FIGHT {…"over":"win"…}` 한 줄(같은 시드면 같은 줄). 전투 화면 한 장: `SHOT_W=1280 SHOT_H=720 tools/xvfb_shot.sh` 에 `--fight-test` 를 붙인다
- castle_common 다시 받기: `cd ../castle_common && python3 -B tools/sync.py castle_strategy` → 이 폴더에서 `python3 -B scripts/verify.py` → `CHANGELOG.md` 의 [깨짐] 확인 → "castle_common <커밋> 받음" 커밋
- 화면 한 장 찍기(가상 화면): `tools/xvfb_shot.sh` — 사용법은 파일 머리에 있다. 장면을 고르려면 뒤에 게임 인자(예 `--view report --week 3` · `--view card --zone namgu` · `--view battle` — `src/launch.gd` 머리)
- 인물 초상 다시 그리기(벡터 일러스트 · 멱등 · 추가 설치 없음): `python3 -B scripts/draw_portraits.py` — 원본은 `assets/chars/looks.json`(외형 표 · 손으로 고쳐도 됨). 점검만: `python3 -B scripts/draw_portraits.py --check`
- 폰에서 하기: 휴대폰 GitHub 앱 → `castle_strategy` → Releases → 맨 위 릴리스의 APK(`docs/폰확인.md`)

## 문서 (이 목록이 유일하다)
| 문서 | 무엇 |
|---|---|
| `CLAUDE.md` | 작업 규칙(사용자 규칙 1~5 · SOLID · TDD · 배포 · castle_common 약속) |
| `docs/기획_차이.md` | 기획서 08 · 개발 규격과 이 판이 다른 곳 · 사용자 답 원문 |
| `docs/castle_common_요청.md` | castle_common 에 넘길 고칠 거리(지금 막힘 없음 — 남은 것은 1 · 2층 값 · 공개 판 예외) |
| `docs/C1_요구사항정의서_시뮬코어.md` | C1(C1-0 기술 검증 + 시뮬 코어) 요구사항 · 완료 기준 · 위험 · 비용 |
| `docs/C1_설계서_상태와턴.md` | 상태 · 명령 · 턴 · 결정성(RNG · 해시 · 정수화) · 저장 v1 |
| `docs/C1_테스트결과서_시뮬코어.md` | C1 실행 증거(검증 출력 · CI · APK 지문 · 폰 결과) |
| `docs/C2_요구사항정의서_화면과명령.md` | C2(지도 · 명령 · 턴 끝 보고 화면) 요구사항 · 완료 기준 · 위험 · 비용 |
| `docs/C2_설계서_화면과명령.md` | 화면 구조 · 보기 · 명령 제출(대기 명령 · 미리 보기) · 저장 pending · 그림(5절 — 2026-11-11 벡터 초상으로 정정) · 스크린샷 인자 |
| `docs/C2_테스트결과서_화면과명령.md` | C2 실행 증거(검증 출력 · 커버리지 · CI · 에뮬레이터 · 스크린샷 · 자체 점검 · 폰 결과) |
| `docs/C3_요구사항정의서_습격과일기토.md` | C3(습격 · 작전 카드 · 일기토 · 전투 화면 · A 완주) 요구사항 · 완료 기준 · 위험 · 비용 |
| `docs/C3_설계서_습격과일기토.md` | 습격 · 일기토 · 승패 모듈 · 명령 묶기 · 틱 규칙 · 차지 뒤 · 화면 · 저장 · 해시 |
| `docs/C3_테스트결과서_습격과일기토.md` | C3 실행 증거(검증 출력 · 커버리지 · CI · 에뮬레이터 · 스크린샷 · 자체 점검 · 폰 결과) |
| `docs/C4_요구사항정의서_직접조작전투.md` | C4(직접 조작 실시간 전투 · 전투 방식 셋 · 구간 결과 · 저장 v2) 요구사항 · 배치 · 완료 기준 · 위험 · 비용 |
| `docs/C4_테스트결과서_직접조작전투.md` | C4 실행 증거 — 배치마다 더한다(C4-0: 검증 출력 · 커버리지 · 서버 실측 · 스크린샷 · 자체 점검 · CI) |
| `docs/C4_설계서_직접조작전투.md` | 구간 계약(need · 구간 결과 · 검증) · 턴 나누기 · 실시간 판정(castle_M3D 이식 표 · 환산식) · 전투 화면 · 저장 v2 · 시험 · 배치와 파일 |
| `docs/성능.md` | 성능 예산(fps · 켜기 · 주 처리 · APK)과 서버 · CI · 폰 실측 |
| `docs/폰확인.md` | 릴리스 본문 — 폰에서 할 일(설치 · 1분 경로 · 볼 것 — 지금 C3) |
| `assets/ASSETS.md` | 자산 출처(verify 가 검사) |
| `docs/트러블슈팅.md` | 겪은 문제(T-n — 증상 · 원인 · 조치) |
| `docs/크레딧_기록.md` | 비용 기록 — `tools/credit.py` 가 쓴다 |
| `history/` | 세션마다 종료 상태 · 다음 단계 |

## 폴더
- 코드: `sim/`(판정 — 순수 · 노드 없음 · 명령 처리기 `sim/kinds/`) · `fight/`(실시간 구간 전투 판정 — 순수 · 60프레임 고정 · castle_M3D 에서 옮김 · C4) · `ui/`(화면 · 테마 · 전투 화면 `ui/fight3d/`) · `src/`(진입 · 실행 인자 · 데이터 · 저장소 입출력)
- 데이터: `data/common/`(castle_common 받은 사본 — 손대지 않음 · `SOURCE.json` 도장) · `data/game/`(3층 표 — 경제 · 시작값 · 지도 · 규칙 값)
- 시험 · 검증: `tests/`(unit = A · integration = B · 시나리오 A 기준 해시 `tests/integration/golden_a.json`) · `scripts/`(get_godot · verify · emu_check · draw_portraits · cut_portraits — 원작 카드 초상 · 개인 빌드 전용) · `tools/`(rng_ref 기준 구현 · credit · xvfb_shot)
- 빌드 · 자산: `android/`(고정 디버그 키) · `.github/workflows/` · `assets/`
- 문서 · 기록: `docs/` · `history/`
