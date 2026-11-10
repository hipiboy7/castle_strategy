# castle_strategy — 캐슬 제패(가칭)

「캐슬」(웹툰) 비공개 · 비영리 개인용 팬게임이다. 캐슬의 조직 하나를 골라 사업 · 사람 · 구역을 키우고, 다른 조직과 싸워 캐슬을 차지하는 턴제 조직 경영 전략이다. Godot 4 · Android 세로.

- 원작 사실 · 공통 규칙 · 장르 팩은 옆 폴더 `../castle_common` 에서 받는다(읽기만 — `CLAUDE.md` 13절).
- 범위와 구조의 원천은 기획서 08 `../castle_common/docs/기획서/08_캐슬제패_조직경영전략.md` 다.

## 빠른 시작 (작업 서버 — 화면 없는 검증만)
- 엔진 받기: `python3 -B scripts/get_godot.py` — Godot 4.7.2 를 `.tools/` 에 받는다(멱등)
- 전체 검증: `python3 -B scripts/verify.py` — 마지막 줄이 `verify: N/M 통과 · X초 — OK` 이고 종료 코드가 0 이면 통과다
- 화면 한 장 찍기(가상 화면): `tools/xvfb_shot.sh` — 사용법은 파일 머리에 있다
- 폰에서 하기: 휴대폰 GitHub 앱 → `castle_strategy` → Releases → 맨 위 릴리스의 APK(`docs/폰확인.md`)

## 문서 (이 목록이 유일하다)
| 문서 | 무엇 |
|---|---|
| `CLAUDE.md` | 작업 규칙(사용자 규칙 1~5 · SOLID · TDD · 배포 · castle_common 약속) |
| `docs/기획_차이.md` | 기획서 08 · 개발 규격과 이 판이 다른 곳 · 사용자 답 원문 |
| `docs/castle_common_요청.md` | castle_common 에 넘길 고칠 거리(지금 막힘: #14 `games.json` 등록) |
| `docs/C1_요구사항정의서_시뮬코어.md` | C1(C1-0 기술 검증 + 시뮬 코어) 요구사항 · 완료 기준 · 위험 · 비용 |
| `docs/C1_설계서_상태와턴.md` | 상태 · 명령 · 턴 · 결정성(RNG · 해시 · 정수화) · 저장 v1 |
| `docs/C1_테스트결과서_시뮬코어.md` | C1 실행 증거(검증 출력 · CI · APK 지문 · 폰 결과) |
| `docs/폰확인.md` | 릴리스 본문 — 폰에서 할 일(설치 · 1분 경로 · 볼 것) |
| `assets/ASSETS.md` | 자산 출처(verify 가 검사) |
| `docs/크레딧_기록.md` | 비용 기록 — `tools/credit.py` 가 쓴다 |
| `history/` | 세션마다 종료 상태 · 다음 단계 |

## 폴더
- 코드: `sim/`(판정 — 순수 · 노드 없음) · `ui/`(화면 · 테마) · `src/`(진입 · 실행 인자 · 저장소 입출력)
- 시험 · 검증: `tests/`(unit = A · integration = B) · `scripts/`(get_godot · verify · emu_check) · `tools/`(rng_ref 기준 구현 · credit · xvfb_shot)
- 빌드 · 자산: `android/`(고정 디버그 키) · `.github/workflows/` · `assets/`
- 문서 · 기록: `docs/` · `history/`
- C1 본체에서 생긴다: data/common/(castle_common 받은 사본 — 손대지 않음) · data/game/(3층 표)
