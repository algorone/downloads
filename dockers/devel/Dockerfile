FROM ubuntu:noble
LABEL org.opencontainers.image.source=https://github.com/algorone
LABEL org.opencontainers.image.description="Ubuntu: liberoffice, tesseract-ocr, poppler-utils, uv python"
LABEL org.opencontainers.image.licenses=GPL
RUN apt update && apt install -y poppler-utils 
RUN apt install -y tesseract-ocr tesseract-ocr-pol 
RUN apt -y -q install libreoffice \
RUN apt-get clean && apt-get autoclean
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
RUN mkdir /workspace
WORKDIR /workspace
RUN uv venv --python 3.14
RUN uv pip install pydantic
RUN uv pip install jupyterlab
RUN uv pip install ipykernel
RUN uv pip install requests
RUN uv pip install python-dotenv
RUN uv pip install asyncpg
RUN mkdir /workspace/lab
RUN mkdir /algorone

CMD .venv/bin/jupyter lab --ip='*' --port=8888 --allow-root