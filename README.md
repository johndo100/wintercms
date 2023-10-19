# wintercms docker

Docker image for [Winter CMS](https://wintercms.com).

This image include `nginx`, `php8.2` and Winter CMS web installer.

You can pull my image and deploy it:

`podman run -dt -p 3000:80 docker.io/johndo100/wintercms`

Web Installer can access at `http://127.0.0.1:3000/install.html`.

This image does not support Microsoft SQL Server, other SQL is OK.
