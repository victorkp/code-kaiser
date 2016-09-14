setup:
	ngrok http 8080

run:
	perl server.pl

tail:
	tail -f /tmp/code-kaiser

test-opened:
	curl -X POST -F payload=@test/events/pr_opened http://localhost:8080/event_handler

install-dependencies:
	sudo cpan install Async Text::Diff::Parser HTTP::Server::Simple::CGI Data::Dumper \
					  JSON DateTime DateTime::Format::ISO8601
