# SeSAC Oracle XE 21c Database Container

SeSAC 팀프로젝트용 Oracle XE 21c 컨테이너.
사용자/콘텐츠 스키마 분리, DB 계정 권한 분리, 컨테이너 기동 시 자동 DDL 실행.

## 📁 레포 구조

```
SeSAC_SpeechApp_Container_DB/
├── Dockerfile                          # gvenzl/oracle-xe:21-slim 기반
├── docker-compose.yml                  # 로컬 단독 테스트용
├── .env.example                        # 환경변수 샘플
├── .gitignore                          # 비밀번호 파일 Git 제외
├── init/
│   ├── 01_create_schemas.sql.template  # 스키마+계정 생성 템플릿
│   ├── 02_user_schema_ddl.sql            # SPEECHAPP_USER 테이블
│   ├── 03_content_schema_ddl.sql         # SPEECHAPP_CONTENT 테이블
│   ├── 04_permissions.sql                # 권한 부여
│   └── 05_seed_data.sql                  # (선택) 초기 데이터
└── README.md
```

> ⚠️ **보안:** `01_create_schemas.sql.template`만 Git에 추적됨. 실제 `.sql`는 `.gitignore` 처리.

## 🗄️ 스키마 설계

| 스키마 | 테이블 | 용도 |
|--------|--------|------|
| `SPEECHAPP_USER` | `APP_USER`, `USER_PROFILE` | 사용자 인증/프로필 |
| `SPEECHAPP_CONTENT` | `IMAGE_RESOURCE`, `IMAGE_TAG`, `IMAGE_HINT` | 이미지 콘텐츠 메타데이터 |

| 계정 | 권한 |
|------|------|
| `speechapp_app` | `SPEECHAPP_USER` RW, `SPEECHAPP_CONTENT` RO |
| `speechapp_admin` | 두 스키마 모두 RW |

## 🚀 로컬 기동 (단독 테스트)

```bash
# 1. 비밀번호 설정
cp .env.example .env
# .env 파일에서 비밀번호 변경

# 2. init SQL 준비 (최초 1회)
cp init/01_create_schemas.sql.template init/01_create_schemas.sql
# init/01_create_schemas.sql에서 __PLACEHOLDER__를 실제 비밀번호로 교체

# 3. 컨테이너 기동
docker compose up -d

# 4. Healthcheck 대기 (약 2~3분)
docker compose logs -f oracle-xe

# 5. sqlplus 연결 테스트
docker exec -it sesac-oracle-xe sqlplus speechapp_app/AppPass123@localhost/XE
```

## 🔌 연결 정보

| 항목 | 값 |
|------|-----|
| JDBC URL | `jdbc:oracle:thin:@localhost:1521/XE` |
| SID/Service | `XE` |
| App 계정 | `speechapp_app` |
| Admin 계정 | `speechapp_admin` |
| SYS 계정 | `system` |

## 📋 DDL 실행 순서

컨테이너 첫 기동 시 `init/` SQL이 **파일명 순서**로 자동 실행됨:

1. `01_create_schemas.sql` — 사용자/스키마 생성
2. `02_user_schema_ddl.sql` — `APP_USER`, `USER_PROFILE`
3. `03_content_schema_ddl.sql` — `IMAGE_RESOURCE`, `IMAGE_TAG`, `IMAGE_HINT`
4. `04_permissions.sql` — 권한 부여
5. `05_seed_data.sql` — (선택) 초기 데이터

> ⚠️ `01_create_schemas.sql`는 `.gitignore` 처리되어 있으므로 clone 후 수동으로 template → 실제 파일 복사 필요.

## 🔗 관련 레포

- [SeSAC_SpeechApp_Deployment](https://github.com/2026SeSAC-Oracle-Team2/SeSAC_SpeechApp_Deployment) — 전체 서비스 docker-compose
- [SeSAC_SpeechApp_Backend](https://github.com/2026SeSAC-Oracle-Team2/SeSAC_SpeechApp_Backend) — Spring Boot 백엔드
