import logging
from decouple import config
import sqlalchemy

POSTGRES_DB = config("DB_NAME")
POSTGRES_USER = config("DB_USER")
POSTGRES_PASSWORD = config("DB_PASS")
POSTGRES_HOST = config("DB_HOST", default=None)
POSTGRES_PORT = config("DB_PORT", default=None)
TEST_POSTGRES_DB=config("TEST_DB_NAME",default=None)
ECHO_DB=config("ECHO_DB",default=False,cast=bool)

#
DB_ROOT_CERT = config("DB_ROOT_CERT", default=None)
DB_CERT = config("DB_CERT", default=None)
DB_KEY = config("DB_KEY", default=None)
DB_SOCKET_DIR = config("DB_SOCKET_DIR", default="/cloudsql")

DB_CONN_STRING = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}/{POSTGRES_DB}"