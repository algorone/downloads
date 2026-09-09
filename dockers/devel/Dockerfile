FROM ubuntu:noble
RUN apt update && apt install -y poppler-utils \
&& apt install -y tesseract-ocr tesseract-ocr-pol \ 
&& apt install fonts-liberation \
&& apt -y -q install libreoffice \
&& apt-get clean && apt-get autoclean
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
RUN mkdir /workspace
WORKDIR /workspace
RUN uv venv --python 3.14
RUN uv pip install pydantic
RUN uv pip install jupyterlab
RUN uv pip install ipykernel
RUN mkdir /workspace/lab
RUN mkdir /algorone

# RUN uv pip install requests
# RUN uv pip install python-dotenv
# RUN uv pip install asyncpg
# RUN uv pip install ollama
# RUN uv pip install markdown
# RUN uv pip install PyPDF2
# RUN uv pip install pdfminer.six


#hasło 
# RUN mkdir -p /root/.jupyter
# COPY .jupyter/ /root/.jupyter/

CMD .venv/bin/jupyter lab --ip='*' --port=8888 --allow-root