FROM python:3.14-slim
RUN useradd --create-home appuser
WORKDIR /srv
COPY app/ app/
COPY config/ config/
ARG GIT_SHA=local
# PYTHONUNBUFFERED=1: print output straight away, so `docker logs` shows it
ENV GIT_SHA=${GIT_SHA} PORT=8080 PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"
CMD ["python", "-m", "app.main"]
