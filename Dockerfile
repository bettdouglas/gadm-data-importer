FROM python:3.8-slim
RUN python -m pip install --upgrade pip

COPY requirements.txt /opt/app/requirements.txt

COPY *.gpkg *.gpkg
WORKDIR /opt/app

RUN --mount=type=cache,id=custom-pip,target=/root/.cache/pip pip install -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1

RUN python data_importer.py