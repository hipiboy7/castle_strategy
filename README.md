# castle_strategy — 캐슬 제패(가칭)

「캐슬」(웹툰) 비공개 · 비영리 개인용 팬게임이다. 캐슬의 조직 하나를 골라 사업 · 사람 · 구역을 키우고, 다른 조직과 싸워 캐슬을 차지하는 턴제 조직 경영 전략이다. Godot 4 · Android 세로.

- 원작 사실 · 공통 규칙 · 장르 팩은 옆 폴더 `../castle_common` 에서 받는다(읽기만 — `CLAUDE.md` 13절).
- 범위와 구조의 원천은 기획서 08 `../castle_common/docs/기획서/08_캐슬제패_조직경영전략.md` 다.

## 빠른 시작 (작업 서버 — 화면 없는 검증만)
지금은 C0(기획/설계)이 끝난 상태다. 아래 명령은 C1-0 에서 생긴다.
- 엔진 받기: `python3 -B scripts/get_godot.py`
- 전체 검증: `python3 -B scripts/verify.py` — 마지막 줄이 `verify: N/M 통과 · Xs — OK` 이고 종료 코드가 0 이면 통과다.
- 폰에서 하기: 휴대폰 GitHub 앱 → `castle_strategy` → Releases → 맨 위 릴리스의 APK.

## 문서 (이 목록이 유일하다)
| 문서 | 무엇 |
|---|---|
| `CLAUDE.md` | 작업 규칙(사용자 규칙 1~5 · SOLID · TDD · 배포 · castle_common 약속) |
| `docs/기획_차이.md` | 기획서 08 · 개발 규격과 이 판이 다른 곳 · 사용자 답 원문 |
| `docs/castle_common_요청.md` | castle_common 에 넘길 고칠 거리(지금 막힘: #14 `games.json` 등록) |
| `docs/C1_요구사항정의서_시뮬코어.md` | C1(C1-0 기술 검증 + 시뮬 코어) 요구사항 · 완료 기준 · 위험 · 비용 |
| `docs/C1_설계서_상태와턴.md` | 상태 · 명령 · 턴 · 결정성(RNG · 해시 · 정수화) · 저장 v1 |
| `docs/크레딧_기록.md` | 비용 기록 — `tools/credit.py` 가 쓴다 |
| `history/` | 세션마다 종료 상태 · 다음 단계 |

## 폴더
- `docs/` 문서 · `history/` 세션 기록 · `tools/` 작업 도구(`credit.py`)
- C1-0 부터 생긴다:
  - 코드: `sim/`(규칙 — 순수) · `ui/`(화면) · `src/`(진입 · 입출력)
  - 시험 · 스크립트: `tests/` · `scripts/`
  - 데이터 · 자산: `data/common/`(받은 사본 — 손대지 않음) · `data/game/`(3층 표) · `assets/`
  - 빌드: `android/` · `.github/workflows/`
