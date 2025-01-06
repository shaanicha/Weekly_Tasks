# Use a base image with Python (for example)
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any dependencies (e.g., via pip for Python)
RUN pip install --no-cache-dir -r requirements.txt

# Expose the port the app will run on
EXPOSE 5000

# Define the command to run the app
# Replace the CMD to run Gunicorn
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
