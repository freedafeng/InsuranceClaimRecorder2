import os
import uuid
import json
from datetime import datetime

import cv2
import piexif
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse

from config import UPLOADS_DIR, SNAPSHOT_COUNT

app = FastAPI()


@app.get("/health")
async def health_check():
    return {"status": "healthy"}


@app.post("/upload")
async def upload_video(file: UploadFile = File(...), metadata: str = Form(...)):
    try:
        # Generate a unique ID for the upload
        timestamp_id = (
            datetime.now().strftime("%Y%m%d%H%M%S") + "_" + str(uuid.uuid4())[:8]
        )
        upload_dir = os.path.join(UPLOADS_DIR, timestamp_id)
        os.makedirs(upload_dir)

        # Save the video file
        video_path = os.path.join(upload_dir, file.filename)
        with open(video_path, "wb") as buffer:
            buffer.write(await file.read())

        # Save the metadata
        metadata_dict = json.loads(metadata)
        metadata_path = os.path.join(upload_dir, "metadata.json")
        with open(metadata_path, "w") as f:
            json.dump(metadata_dict, f, indent=4)

        # Create snapshots
        snapshots_dir = os.path.join(upload_dir, "snapshots")
        os.makedirs(snapshots_dir)

        cap = cv2.VideoCapture(video_path)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        frame_indices = [
            int(i * total_frames / SNAPSHOT_COUNT) for i in range(SNAPSHOT_COUNT)
        ]

        for i, frame_index in enumerate(frame_indices):
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
            ret, frame = cap.read()
            if ret:
                snapshot_path = os.path.join(snapshots_dir, f"snapshot_{i + 1}.jpg")
                cv2.imwrite(snapshot_path, frame)

                # Add EXIF data
                add_exif_data(snapshot_path, metadata_dict)

        cap.release()

        return JSONResponse(
            content={"message": "Upload successful", "id": timestamp_id},
            status_code=200,
        )

    except Exception as e:
        return JSONResponse(
            content={"message": f"An error occurred: {str(e)}"}, status_code=500
        )


def add_exif_data(image_path, metadata):
    try:
        exif_dict = {"0th": {}, "Exif": {}, "GPS": {}, "1st": {}, "thumbnail": None}

        if "focalLength" in metadata:
            exif_dict["Exif"][piexif.ExifIFD.FocalLength] = (
                int(metadata["focalLength"] * 100),
                100,
            )
        if "zoomFactor" in metadata:
            exif_dict["Exif"][piexif.ExifIFD.DigitalZoomRatio] = (
                int(metadata["zoomFactor"] * 100),
                100,
            )
        if "latitude" in metadata and "longitude" in metadata:
            exif_dict["GPS"][piexif.GPSIFD.GPSLatitudeRef] = (
                b"N" if metadata["latitude"] >= 0 else b"S"
            )
            exif_dict["GPS"][piexif.GPSIFD.GPSLatitude] = decimal_to_dms(
                abs(metadata["latitude"])
            )
            exif_dict["GPS"][piexif.GPSIFD.GPSLongitudeRef] = (
                b"E" if metadata["longitude"] >= 0 else b"W"
            )
            exif_dict["GPS"][piexif.GPSIFD.GPSLongitude] = decimal_to_dms(
                abs(metadata["longitude"])
            )

        exif_bytes = piexif.dump(exif_dict)
        piexif.insert(exif_bytes, image_path)
    except Exception as e:
        print(f"Failed to write EXIF data: {e}")


def decimal_to_dms(decimal_coord):
    degrees = int(decimal_coord)
    minutes_float = (decimal_coord - degrees) * 60
    minutes = int(minutes_float)
    seconds_float = (minutes_float - minutes) * 60
    return ((degrees, 1), (minutes, 1), (int(seconds_float * 100), 100))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
