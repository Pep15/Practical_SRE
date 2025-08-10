
from flask import Flask, jsonify, request, Response, g
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, REGISTRY
import time
import os
import requests
import jwt
import logging
from flask_cors import CORS
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import User, Base
from config import DATABASE_URL

# (Logging)
app_logger = logging.getLogger(__name__) 
app_logger.setLevel(logging.INFO) 

handler = logging.StreamHandler()
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
app_logger.addHandler(handler)

log = logging.getLogger('werkzeug')
log.setLevel(logging.WARNING) 

app = Flask(__name__)
app.logger.handlers = app_logger.handlers
app.logger.setLevel(app_logger.level)

CORS(app, origins=["https://webportal.local"])

# --- Database Setup ---
engine = create_engine(DATABASE_URL)
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)

# --- Global Configurations ---
JWT_SECRET = os.getenv("JWT_SECRET", "secret123")
IMAGE_SERVICE_URL = os.getenv("IMAGE_SERVICE_URL", "http://image-service:8082")
AUTH_SERVICE_URL = os.getenv("AUTH_SERVICE_URL", "http://auth-service:8080")

# --- Prometheus Metrics ---
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'http_status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Latency of HTTP requests in seconds', ['method', 'endpoint', 'http_status'])
IN_PROGRESS = Gauge('http_requests_in_progress', 'In-progress HTTP requests', ['method', 'endpoint'])

# --- Middleware for Metrics ---
@app.before_request
def before_request_hook():
    g.request_start_time = time.time()
    IN_PROGRESS.labels(method=request.method, endpoint=request.path).inc()

@app.after_request
def after_request_hook(response):
    duration = time.time() - g.request_start_time
    method = request.method
    endpoint = request.path
    status_code = response.status_code

    REQUEST_COUNT.labels(method=method, endpoint=endpoint, http_status=str(status_code)).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint, http_status=str(status_code)).observe(duration)
    IN_PROGRESS.labels(method=method, endpoint=endpoint).dec()
    return response

# --- Routes ---
@app.route('/')
def home():
    app.logger.info("Home route accessed.") 
    return 'API Service is running!'

@app.route('/register', methods=['POST'])
def register():
    app.logger.info("Register route accessed.") 
    session = Session()
    try:
        name = request.form.get('name')
        email = request.form.get('email')
        password = request.form.get('password')
        image = request.files.get('image')

        if session.query(User).filter_by(email=email).first():
            app.logger.warning(f"Registration failed: User with email {email} already exists.")
            return jsonify({"error": "User already exists"}), 409

        image_url = None
        if image:
            try:
                files = {'image': (image.filename, image.stream, image.mimetype)}
                res = requests.post(f"{IMAGE_SERVICE_URL}/images/upload", files=files, timeout=60)
                res.raise_for_status()

                if res.headers.get('Content-Type') == 'application/json':
                    image_response_data = res.json()
                    image_url = image_response_data.get('image_url')
                    if not image_url:
                        app.logger.error(f"Image service response missing image_url: {image_response_data}")
                        return jsonify({"error": "Image service response malformed (no image_url)"}), 500
                else:
                    app.logger.error(f"Image service returned non-JSON content (Status: {res.status_code}): {res.text}")
                    return jsonify({"error": f"Image service returned unexpected content (Status: {res.status_code})"}), 500

            except requests.exceptions.Timeout:
                app.logger.error("Image service request timed out.")
                return jsonify({"error": "Image upload service timed out"}), 504
            except requests.exceptions.ConnectionError as conn_err:
                app.logger.error(f"Image service connection error: {conn_err}")
                return jsonify({"error": "Could not connect to image upload service"}), 503
            except requests.exceptions.HTTPError as http_err:
                app.logger.error(f"Image service HTTP error (Status: {http_err.response.status_code}): {http_err.response.text}")
                return jsonify({"error": f"Image upload failed (HTTP error: {http_err.response.status_code})"}), 500
            except ValueError as json_err:
                app.logger.error(f"Failed to parse image service JSON response: {json_err}")
                return jsonify({"error": "Image upload failed (invalid JSON response)"}), 500
            except Exception as upload_err:
                app.logger.error(f"Unexpected error during image upload: {upload_err}")
                return jsonify({"error": "Image upload failed (unexpected error)"}), 500

        new_user = User(name=name, email=email, password=password, image_url=image_url)
        session.add(new_user)
        session.commit()

        app.logger.info(f"User {email} registered successfully.")
        return jsonify({"message": "User registered successfully"}), 201
    except Exception as e:
        session.rollback()
        app.logger.error(f"Error during registration (main block): {e}", exc_info=True) # exc_info=True لطباعة Stack Trace
        return jsonify({"error": "Internal server error during registration"}), 500
    finally:
        session.close()

@app.route('/login', methods=['POST'])
def login():
    app.logger.info("Login route accessed.")
    try:
        data_from_frontend = request.get_json(silent=True)

        if data_from_frontend is None:
            raw_data = request.data.decode('utf-8', errors='ignore')
            app.logger.error(f"Failed to parse JSON from frontend. Raw data: '{raw_data}'")
            return jsonify({"error": "Invalid JSON format from client"}), 400

        app.logger.info(f"Received JSON data from frontend: {data_from_frontend}")
        app.logger.info(f"Sending JSON data to Auth service: {data_from_frontend}")

        res = requests.post(f"{AUTH_SERVICE_URL}/auth", json=data_from_frontend, timeout=60)
      
        if res.status_code == 401:
            app.logger.warning(f"Authentication failed for user: {data_from_frontend.get('email')}")
            
            return jsonify({"error": "Authentication failed: Invalid credentials"}), 401
        
        res.raise_for_status() 

        app.logger.info(f"Auth service responded with status {res.status_code}.")
        return jsonify(res.json()), res.status_code
    except requests.exceptions.RequestException as e:
        app.logger.error(f"Error communicating with Auth service during login: {e}", exc_info=True)
        return jsonify({"error": "Failed to communicate with Auth service"}), 503
    except Exception as e:
        app.logger.error(f"Unexpected error in API login: {e}", exc_info=True)
        return jsonify({"error": "Internal server error"}), 500
    
@app.route('/profile', methods=['GET'])
def profile():
    app.logger.info("Profile route accessed.") 
    session = Session()
    try:
        token = request.headers.get('Authorization', '').replace("Bearer ", "")
        payload = jwt.decode(token, JWT_SECRET, algorithms=['HS256'])
        user = session.query(User).get(payload["user_id"])
        if not user:
            app.logger.warning(f"Profile fetch failed: User with ID {payload.get('user_id')} not found.")
            return jsonify({"error": "User not found"}), 404

        app.logger.info(f"Profile for user {user.email} fetched successfully.")
        return jsonify({
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "image_url": user.image_url
        }), 200
    except jwt.ExpiredSignatureError:
        app.logger.warning("Profile fetch failed: Token expired.")
        return jsonify({"error": "Token expired"}), 401
    except jwt.InvalidTokenError:
        app.logger.warning("Profile fetch failed: Invalid token.")
        return jsonify({"error": "Invalid token"}), 401
    except Exception as e:
        app.logger.error(f"Error during profile fetch: {e}", exc_info=True) 
        return jsonify({"error": "Internal server error"}), 500
    finally:
        session.close()

@app.route('/metrics')
def metrics():
    app.logger.info("Metrics route accessed.") 
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


if __name__ == '__main__':
    try:
        app_logger.info("Starting API Service...") 
        app.run(host='0.0.0.0', port=8081, debug=True)
    except Exception as e:
        app_logger.critical(f"Failed to start API Service: {e}", exc_info=True) # 
