# Open new gnoem-terminal windows for starting ngrok and tail'ing the logs
setup:
	gnome-terminal -e "ngrok http 8080"
	gnome-terminal --working-directory="${CURDIR}" -e "make tail"

# Run the code review server
run:
	perl server.pl

ngrok:
	ngrok http 8080

# View logs with tail
tail:
	tail -f /tmp/code-kaiser

# DateTime had install problems on RedHat through cpan, so switched that to use DNF, you will need to switch back to CPAN if not on RedHat/Fedora
install-dependencies:
	sudo cpan install --force Async Text::Diff::Parser HTTP::Server::Simple::CGI Data::Dumper \
							  JSON DateTime DateTime::Format::Builder DateTime::Format::ISO8601 \
							  Data::Structure::Util
	sudo dnf install -y perl-DateTime*
