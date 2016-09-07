setup:
	ngrok http 8080

run:
	perl server.pl

tail:
	tail -f /tmp/code-kaiser

install-dependencies:
	sudo cpan install Async Text::Diff::Parser HTTP::Server::Simple::CGI Data::Dumper \
					  JSON
