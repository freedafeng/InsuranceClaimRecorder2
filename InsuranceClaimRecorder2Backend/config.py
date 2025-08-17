import os

UPLOADS_DIR = "uploads"
SNAPSHOT_COUNT = 100

# Create the uploads directory if it doesn't exist
if not os.path.exists(UPLOADS_DIR):
    os.makedirs(UPLOADS_DIR)
