# Use AWS Lambda Web Adapter
FROM public.ecr.aws/awsguru/aws-lambda-adapter:0.7.0 AS lambda-adapter
FROM python:3.11-slim

# Copy the lambda adapter
COPY --from=lambda-adapter /lambda-adapter /opt/extensions/

# Create a non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app

# Install the app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py .

# Switch to non-root
USER appuser
EXPOSE 8080

# Same command for both local and Lambda, thanks to the adapter
CMD ["python", "main.py"]