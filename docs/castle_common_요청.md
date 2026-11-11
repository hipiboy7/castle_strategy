# castle_common 요청 — castle_strategy(캐슬 제패) → castle_common

> 정정 이력: 2026-11-10 — 첫 작성(C0). castle_common `98ac39cc` 를 읽기만 해서 기계로 점검했다. 대상은 기획서 08 15절의 받을 데이터와 장르 팩 `packs/strategy/` 다.
> 2026-11-10(C1 본체) — castle_common `56839ec`(91차)를 받고 기계로 다시 점검했다. 반영된 #1~15 · #18~23 · #28 을 지웠다(사건 `join` · `duel.fight` · `games.json` 등록 · cases `one_shot` 225 · 문서 id · F 명단). #25 ~ #27 은 남은 수를 고쳤다. #16 · #17 · #24 ~ #27 · #29 는 castle_common 이 사용자 답을 기다린다(castle_common `docs/인터뷰/2026-11-10_하류요청_castle_srpg_strategy.md` 2 ~ 5 · 8절).
> 2026-11-11 — #30 [정리](castle_srpg 폐지 · 삭제 — 사용자) · #31(직접 조작 전투가 쳐내기 규칙을 따름)을 더했다.

- **넘기는 법**: 이 파일의 경로(`castle_strategy/docs/castle_common_요청.md`)를 castle_common 세션에 알려 준다. 같은 PC 면 경로만으로 된다. castle_common 이 반영하면 그 줄을 지우고, 번호는 다시 쓰지 않는다.
- **순서**(캐슬 규격 3절):
  - 원작 위치가 있는 줄을 먼저, 화 → 컷 오름차순으로 둔다(1부 `p1:` 를 먼저).
  - 위치가 없는 줄(데이터 칸 · 규격)은 그 뒤에 `파일:id` 순으로 둔다.
- 2층 값(등급 · 능력치)은 '바랄 값'에 후보만 적는다. 확정은 사용자가 한다.
- **급함**:
  - **막힘** — 판이 멈춘다.
  - **다음 마일스톤**
  - **언젠가**
- 지금 막힘은 없다(#14 등록 · 받기 2026-11-10 — castle_common `56839ec`). 이 판은 남은 빈칸을 provisional 자리값으로 두고 진행한다(`docs/기획_차이.md` (나)9).

| # | 위치 | 파일:id | 칸 | 지금 값 | 바랄 값 | 근거 | 급함 |
|---|---|---|---|---|---|---|---|
| 16 | - | `data/characters.json:baekdochan` | `속도` · `힘` · `맷집` | 기술만 있다 | 사용자 확정 값. 없으면 08 14-2 · 14-3 의 '값 없는 인물' 규칙으로 계산한다 | 08 일기토 속도 순서에 `속도` 가 필요하다. 08 은 값이 없을 때의 대체값을 정하지 않았다 | 다음 마일스톤(C3) |
| 17 | - | `data/ranks.json:below` | '그 아래급' | 사다리 15 밖이라 `rank_index` 가 오류를 낸다 | 사다리 안 등급으로 대응시킬지(예: 건달급) 정해 둔다 | 명단 · 강함표에 '그 아래급'이 나오면 판이 계산할 수 없다 | 다음 마일스톤(C3) |
| 29 | - | `docs/개발규격/캐슬_게임공통.md` 머리 · 2절 10항 | '판 저장소는 모두 private · 공개 전환 금지' | castle_M3D(지금 공개 · 2026-10-26 공개 기록) · castle_strategy(2026-11-10~)가 사용자 지시로 공개다 | 사용자가 정한다 — 규격에 공개 판 예외를 적을지(예: '사용자 지시로 공개할 수 있다 · 공개인 동안 원작 대사 · 컷은 올리지 않는다'), 판들을 비공개로 되돌릴지 | 규격과 실제가 달라 다음 세션들이 규칙 위반으로 보고 멈춘다(castle_strategy `docs/기획_차이.md` (다)12) | 다음 마일스톤 |
| 30 | - | `games.json:castle_srpg` · `games.json:castle_tactics` | [정리] `status` · `receives` · `dest` · `note` | castle_srpg `status: active` · `receives` 7줄 · `dest: castle_srpg/data/common` · castle_tactics note '2026-11-10 castle_srpg 가 이어받음' | castle_srpg: `status` 를 폐지 값(예 `retired` — castle_common 이 쓰는 값으로) · `receives: []` · `dest: ""` · note 앞에 '2026-11-11 사용자 — 전술 SRPG 폐지 · 원격 저장소 `hipiboy7/castle_srpg` · 로컬 사본 삭제. id 는 영구라 지우지 않음'. castle_tactics note 에도 '이어받은 castle_srpg 도 2026-11-11 폐지' 한 줄 | 사용자 2026-11-11 지시(`docs/기획_차이.md` (라)18 5). 원격 · 로컬 저장소가 없어 sync 가 옛 dest 로 받으면 빈 폴더를 만든다 | 다음 마일스톤 |
| 31 | - | `games.json:castle_strategy` | `follows` · `note` | `follows` 에 `rules/전투_쳐내기.md` 없음 · note '쳐내기는 실시간 규칙이라 따르지 않고 일기토 카드 쳐내기로 해석' | `follows` 에 `rules/전투_쳐내기.md` 더함 · note 에 '2026-11-11 직접 조작 실시간 전투(C4 — castle_M3D 판정을 옮김)는 쳐내기 1~3절을 따른다. 틱 자동 전투 · 일기토 카드는 `can_parry` 해석 그대로' | 사용자 2026-11-11 방향 — 직접 조작 전투(`docs/기획_차이.md` (나)41 ~ 46 · (다)9 정정) | 다음 마일스톤(C4) |
| 24 | - | `packs/strategy/characters.json` | `stats`(5능력치) | A 명단 중 `gangmanjae` · `gunter` · `kimhyeokju`, B 는 더해 `gusanghun`, P 는 8명(`gangminseong` · `gwonsuchan` · `pyoseong` · `gwakjungheon` · `wigilseong` · `baekganghoe` · `ssanggae` · `jeongpilseong`)에 없다 | AI 후보 → 사용자 확정 | 간부 행동 · 공작 성공률에 계산 · 수완 · 의리가 필요하다(08 14-1 · 14-4) | 다음 마일스톤(C1 본체 — A 3명) |
| 25 | - | `packs/strategy/scenarios.json:A` | `roster[].rank` | null 4/14: `chasumin` · `icheolmin` · `kimseongyu` · `risa`(91차에 `data/characters.json` 처음 등급으로 6명이 채워짐 — `rank_src` · 그중 `rank_provisional` 4) | 후보를 사용자가 확정한다. 비전투 인물(정치 · 중개)은 `noncombat: true` 도 된다(castle_common 인터뷰 3절) | 간부 대우비(08 14-1 등급 번호 × 3) · 습격 · 일기토(14-2 · 14-3)가 등급으로 계산된다. 그 전엔 판이 자리값 `조장급` + `rank_prov` 로 둔다 | 다음 마일스톤(C3) |
| 26 | - | `packs/strategy/scenarios.json:B` | `roster[].rank` | null 15/51(91차에 기둥 사람 7명을 `early` 로 더함) | 후보 → 사용자 확정 | #25 와 같은 까닭 | 다음 마일스톤(C6 — 2026-11-11 재설계로 C5 에서 밀림) |
| 27 | - | `packs/strategy/scenarios.json:C` · `D` · `E` · `F` · `P` | `roster[].rank` | null — C 29/76 · D 50/109 · E 51/104 · F 59/128 · P 9/13(56839ec) | #25 와 같은 방식 | 같은 까닭 | 언젠가(C7 — 2026-11-11 재설계로 C6 에서 밀림) |

## #14 등록 내용 (castle_common `games.json` `games[]` 에 더할 줄 — 허용 칸만)
```json
{
  "id": "castle_strategy",
  "name": "캐슬 제패(가칭) — 조직 경영 전략",
  "engine": "godot-4",
  "status": "active",
  "receives": ["data/*.json", "cases/*.json", "canon/*.json", "packs/strategy/*.json", "docs/개발규격/*.md"],
  "dest": "castle_strategy/data/common",
  "follows": ["rules/등급과_게이지.md", "rules/기술.md", "docs/개발규격/캐슬_게임공통.md", "docs/개발규격/게임개발규격.md"],
  "platforms": ["android"],
  "note": "2026-11-10 사용자 — 기획서 08 의 새 판(제안 id castle_conquest → castle_strategy). Godot 4.7.2-stable · 세로. canon/episodes(대사 원문 · 9.8MB)는 원작 사건 컷인(C6) 때 더한다. 쳐내기(rules/전투_쳐내기.md)는 실시간 규칙이라 따르지 않고 일기토 카드 '쳐내기'(can_parry)로 해석한다 — castle_tactics 와 같다"
}
```
- 받는 곳: base = castle_common 의 상위 폴더 → `castle_strategy/data/common/`. 받은 뒤 이 판의 `scripts/verify.py` 가 `SOURCE.json` sha256 을 검사한다.
- 받은 뒤 이 판에서 할 일: cases 3005줄을 `sim/rules_common.gd` 로 1e-9 안에서 맞춘다(C1 본체). README '반영 현황' 갱신 거리는 그때 목록으로 넘긴다.
- 결과(2026-11-10): 등록됨(castle_common `56839ec`) · 받음 · cases 3215줄 다름 0(`tests/unit/test_common_cases.gd`). castle_common README '반영 현황' 갱신 거리: castle_strategy 가 `56839ec` 를 받았다.
