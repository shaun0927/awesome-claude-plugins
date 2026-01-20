# Multi-Account Switcher for Claude Code

다중 Claude 계정을 관리하고 사용량 기반으로 자동 전환하는 플러그인입니다.

---

## Features

### 1. Multi-Account Management
- 여러 Claude 계정 등록 및 관리
- 계정별 OAuth 토큰 안전 저장
- 크로스 플랫폼 지원 (macOS, Linux, Windows)

### 2. Usage Monitoring
- 모든 계정의 5H/7D 사용량 실시간 모니터링
- 사용량 기반 가용성 점수 계산
- 캐싱으로 API 호출 최소화

### 3. Automatic Switching
- 설정된 임계값 초과 시 자동 계정 전환
- 세션 시작 시 최적 계정 선택
- 수동 전환도 지원

### 4. Statusline Integration
- 현재 계정 및 모든 계정 사용량 표시
- Catppuccin 테마 그라데이션 색상
- 실시간 업데이트

---

## Installation

```bash
# 1. 플러그인 디렉토리로 이동
cd ~/.claude/plugins

# 2. 저장소 클론
git clone https://github.com/YOUR_USERNAME/awesome-claude-plugins.git

# 3. 스크립트 실행 권한 부여
chmod +x awesome-claude-plugins/plugins/multi-account-switcher/scripts/*.sh
```

---

## Quick Start

### Step 1: 첫 번째 계정 추가

현재 로그인된 계정을 등록합니다:

```
/multi-account-add
```

### Step 2: 추가 계정 등록

1. Claude Code에서 `/logout`
2. `/login`으로 다른 계정 로그인
3. `/multi-account-add`로 등록
4. 필요한 만큼 반복

### Step 3: 자동 전환 설정

```
/multi-account-auto on           # 자동 전환 활성화
/multi-account-auto threshold 80 # 80% 사용 시 전환
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/multi-account-add` | 현재 로그인된 계정 등록 |
| `/multi-account-list` | 모든 계정 및 사용량 표시 |
| `/multi-account-switch <name>` | 특정 계정으로 수동 전환 |
| `/multi-account-auto` | 자동 전환 설정 |
| `/multi-account-status` | 상세 상태 보기 |

---

## Auto-Switch Logic

### 작동 방식

```
┌─────────────────────────────────────────────────────────────┐
│                    Session Start                             │
├─────────────────────────────────────────────────────────────┤
│  1. 현재 계정의 5H 사용량 확인                                │
│  2. 임계값(기본 80%) 초과 여부 판단                           │
│  3. 초과 시 → 모든 계정의 사용량 조회                         │
│  4. 가장 여유로운 계정 선택                                   │
│  5. 자동 전환 실행                                           │
└─────────────────────────────────────────────────────────────┘
```

### 가용성 점수 계산

```
Score = 100 - (5H_usage × 0.7 + 7D_usage × 0.3)
```

- 5H 사용량에 더 높은 가중치 (더 빨리 리셋되므로)
- 점수가 높을수록 해당 계정 우선 사용

---

## Statusline Display

### Default Mode (2줄)

```
🤖 Claude Opus | 👤 work | 🧠 ███░░ 45%
▶work: 5H 25% 7D 40% │ personal: 5H 85% 7D 60% │ backup: 5H 15% 7D 20%
```

### Visual Indicators

| Usage | Color | Status |
|-------|-------|--------|
| 0-40% | Green | Available |
| 40-70% | Yellow | Moderate |
| 70-90% | Orange | Limited |
| 90-100% | Red | Exhausted |

---

## Configuration

설정 파일: `~/.claude/multi-accounts.json`

```json
{
  "accounts": [
    {
      "name": "work",
      "email": "work@example.com",
      "token": "<encrypted>",
      "added_at": "2026-01-20T10:00:00+09:00"
    }
  ],
  "settings": {
    "auto_switch": true,
    "threshold": 80
  }
}
```

---

## Platform Support

| Platform | Token Storage | Status |
|----------|---------------|--------|
| macOS | Keychain | Full support |
| Linux | secret-tool | Full support |
| Windows | credentials.json | Full support |

---

## Troubleshooting

### 계정이 추가되지 않음
- Claude Code에 로그인되어 있는지 확인
- `jq` 설치 여부 확인: `jq --version`

### 자동 전환이 작동하지 않음
- `/multi-account-auto` 설정 확인
- 임계값이 너무 높게 설정되어 있지 않은지 확인
- 로그 확인: `~/.claude/account-switch.log`

### 사용량이 표시되지 않음
- 네트워크 연결 확인
- API 호출 캐시 삭제: `rm /tmp/.claude_multi_account/*`

---

## Requirements

- Claude Code CLI (최신 버전)
- `jq` (JSON 처리)
- `curl` (API 호출)
- 플랫폼별:
  - macOS: `security` (기본 설치됨)
  - Linux: `secret-tool`
  - Windows: 없음 (파일 기반)

---

## Security Notes

- 토큰은 Base64 인코딩되어 저장 (추가 암호화 권장)
- 설정 파일은 사용자 홈 디렉토리에 저장
- 전환 로그가 기록됨

---

## License

MIT License

---

## Credits

- 원본 저장소: [awesomejun/awesome-claude-plugins](https://github.com/awesomejun/awesome-claude-plugins)
- Catppuccin 색상 팔레트
- Claude Code 팀
