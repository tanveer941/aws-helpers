FROM python:3.8-slim
WORKDIR /app
EXPOSE 80
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
ENTRYPOINT ["python", "runner.py"]