deploy:
	ssh isu11f-1 " \
		cd /home/isucon; \
		git checkout .; \
		git fetch; \
		git checkout $(BRANCH); \
		git reset --hard origin/$(BRANCH)"

build:
	ssh isu11f-1 " \
		cd /home/isucon/webapp/go; \
		/home/isucon/local/go/bin/go build -o isucholar"

go-deploy:
	scp ./webapp/go/isucholar isu11f-1:/home/isucon/webapp/go/

go-deploy-dir:
	scp -r ./webapp/go isu11f-1:/home/isucon/webapp/

restart:
	ssh isu11f-1 "sudo systemctl restart isucholar.go.service"

mysql-deploy:
	ssh isu11f-1 "sudo dd of=/etc/mysql/mysql.conf.d/mysqld.cnf" < ./etc/mysql/mysql.conf.d/mysqld.cnf

mysql-rotate:
	ssh isu11f-1 "sudo rm -f /var/log/mysql/mysql-slow.log"

mysql-restart:
	ssh isu11f-1 "sudo systemctl restart mysql.service"

nginx-deploy:
	ssh isu11f-1 "sudo dd of=/etc/nginx/nginx.conf" < ./etc/nginx/nginx.conf
	ssh isu11f-1 "sudo dd of=/etc/nginx/sites-enabled/isucholar.conf" < ./etc/nginx/sites-available/isucholar.conf

nginx-rotate:
	ssh isu11f-1 "sudo rm -f /var/log/nginx/access.log"

nginx-reload:
	ssh isu11f-1 "sudo systemctl reload nginx.service"

nginx-restart:
	ssh isu11f-1 "sudo systemctl restart nginx.service"

env-deploy:
	ssh isu11f-1 "sudo dd of=/home/isucon/env.sh" < ./env.sh
	ssh isu11f-2 "sudo dd of=/home/isucon/env.sh" < ./env.sh

.PHONY: bench
bench:
	ssh isu11f-bench " \
		cd /home/isucon/benchmarker; \
		./bin/benchmarker -target 172.31.41.7:443 -tls"

journalctl:
	ssh isu11f-1 "sudo journalctl -xef"

nginx-log:
	ssh isu11f-1 "sudo tail -f /var/log/nginx/access.log"

pt-query-digest:
	ssh isu11f-1 "sudo pt-query-digest --limit 10 /var/log/mysql/mysql-slow.log"

ALPSORT=sum
# ^/api/announcements/[A-Za-z0-9]{26}
# ^/api/announcements\?
# ^/api/courses/[A-Za-z0-9]{26}/classes/[A-Za-z0-9]{26}/assignments
# ^/api/courses/[A-Za-z0-9]{26}/classes
# ^/api/courses/[A-Za-z0-9]{26}/status
# ^/api/courses/[A-Za-z0-9]{26}
# ^/api/courses\?
ALPM=^/api/announcements/[A-Za-z0-9]{26},^/api/announcements\?,^/api/courses/[A-Za-z0-9]{26}/classes/[A-Za-z0-9]{26}/assignments,^/api/courses/[A-Za-z0-9]{26}/classes,^/api/courses/[A-Za-z0-9]{26}/status,^/api/courses/[A-Za-z0-9]{26},^/api/courses\?
OUTFORMAT=count,method,uri,min,max,sum,avg,p99

alp:
	ssh isu11f-1 "sudo alp ltsv --file=/var/log/nginx/access.log --nosave-pos --pos /tmp/alp.pos --sort $(ALPSORT) --reverse -o $(OUTFORMAT) -m $(ALPM) -q"

.PHONY: pprof
pprof:
	ssh isu11f-1 " \
		/home/isucon/local/go/bin/go tool pprof -seconds=100 /home/isucon/webapp/go/isucholar http://localhost:6060/debug/pprof/profile"

pprof-show:
	$(eval latest := $(shell ssh isu11f-1 "ls -rt ~/pprof/ | tail -n 1"))
	scp isu11f-1:~/pprof/$(latest) ./pprof
	go tool pprof -http=":1080" ./pprof/$(latest)

pprof-kill:
	ssh isu11f-2 "pgrep -f 'pprof' | xargs kill;"
