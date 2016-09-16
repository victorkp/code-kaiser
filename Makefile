setup:
	gnome-terminal -e "ngrok http 8080"
	gnome-terminal --working-directory="${CURDIR}" -e "make tail"

run:
	perl server.pl

tail:
	tail -f /tmp/code-kaiser

test-opened:
	curl -X POST -F payload=@test/events/pr_opened http://localhost:8080/event_handler

install-dependencies:
	sudo cpan install --force Async Text::Diff::Parser HTTP::Server::Simple::CGI Data::Dumper \
							  JSON DateTime DateTime::Format::Builder DateTime::Format::ISO8601
	sudo dnf install -y perl-DateTime*
