docker run -d --name dj-mariadb --network domjudge-net -e MYSQL_ROOT_PASSWORD=root -e MYSQL_USER=user  -e MYSQL_PASSWORD=user -e MYSQL_DATABASE=db -p 13306:3306 --platform linux/amd64 mariadb --max-connections=1000

docker run -d --name domserver --network domjudge-net -e MYSQL_HOST=dj-mariadb -e MYSQL_USER=user -e MYSQL_DATABASE=db -e MYSQL_PASSWORD=user -e MYSQL_ROOT_PASSWORD=root -p 12345:80 --platform linux/amd64 domjudge/domserver:latest
