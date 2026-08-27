# ============================================================
# SeSAC Oracle XE 21c Database Container
# 기반 이미지: gvenzl/oracle-xe:21-slim (Oracle 공식 Community)
# ============================================================
FROM gvenzl/oracle-xe:21-slim

# 컨테이너 기동 시 자동 실행될 init SQL 복사
# /container-entrypoint-initdb.d/ 경로에 SQL을 넣으면
# gvenzl 이미지가 첫 기동 시 자동으로 sqlplus로 실행함
COPY init/*.sql /container-entrypoint-initdb.d/

# Oracle 기본 포트
EXPOSE 1521
EXPOSE 5500

# 환경변수 (런타임에 docker-compose나 -e 플래그로 오버라이드)
ENV ORACLE_PASSWORD=__CHANGE_ME__
ENV APP_USER_PASSWORD=__CHANGE_ME__
ENV ADMIN_USER_PASSWORD=__CHANGE_ME__

# gvenzl 이미지의 기본 entrypoint 유지
