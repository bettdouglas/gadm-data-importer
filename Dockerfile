FROM nikolaik/python-nodejs:python3.8-nodejs18-slim
RUN python -m pip install --upgrade pip

RUN npm install -g mapshaper

COPY requirements.txt /opt/app/requirements.txt

WORKDIR /opt/app

# RUN --mount=type=cache,id=custom-pip,target=/root/.cache/pip 

RUN pip install -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1

CMD python data_importer.py