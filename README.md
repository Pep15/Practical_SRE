Infrastructure and Environment

I set up a Kubernetes environment using Minikube, which serves as an ideal platform for local development.

It provides a flexible space for application testing, troubleshooting, and experimentation.

User interface service:

The user interface for login and registration using HTML and JavaScript.

This interface integrates with the API to handle image uploads, register new users, validate login credentials, and display profiles of users.

API service:

The Application Programming Interface (API) is built using Python to handle data coming from users.

The backend logic processes this data and communicates with other services, applying the Gateway Pattern to manage requests and responses efficiently.

Authentication Service:

The Authentication service is an internal component that verifies user credentials, such as usernames and passwords.

It does not handle direct external requests; instead, it receives data from the main API service.

Built with Python, it processes and validates login information to ensure secure access.

Image service:

Serves as a centralized storage zone for user images, providing access and retrieval capabilities.

Built with Go to ensure performance and scalability.

Docker Containerization:

Docker is a containerization technology that allows you to package applications and their dependencies into isolated units called containers.

I used Docker to build container images, which are then deployed, orchestrated, and managed by Kubernetes.

My Docker image :

'api-service'

'auth-service'

'image-servic'

'webportal-service'

'registry images:' -> used to store the Docker images that are built internally.
