#!/bin/perl
{
    package CodeKaiser::UserStatistics;
    use strict;
    use warnings;
     
    use File::Spec;
    use File::Basename;
    use File::Slurp;
    use Scalar::Util;
    use JSON;
    use Data::Structure::Util qw( unbless );

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(new
                      user_name
                      files_changed
                      files_reviewed
                      file_changed_add_additions
                      file_changed_add_removals
                      file_reviewed_add_additions
                      file_reviewed_add_removals
                      write_user
                      TO_JSON
                     );

    my $JSON = JSON->new->allow_blessed->convert_blessed->pretty;

    # User file path key
    my  $USER_FILE              = 'user_file';

    # User name (login)
    my  $USER_NAME              = 'user_name';

    # Files changed that user is responsible for
    # each file broken down into $LINES_ADDED, and $LINES_REMOVED
    my  $FILES_CHANGED          = 'files_changed';
    
    # Files changed that user has reviewed and approved,
    # each file broken down into $LINES_ADDED, and $LINES_REMOVED
    my  $FILES_REVIEWED          = 'files_reviewed';

    # For each file changed or removed, record additions and deletions
    our $LINES_ADDED             = 'lines_removed';
    our $LINES_REMOVED           = 'lines_added';

    ## Load a pull rules configuration file,
    ## creating a configuration file with defaults
    ## if none exists at specified path
    # Expects { user_file => <filename> }
    sub new($) {
        my ($class, %args) = @_;

        my $user_file = $args{user_file};
        if(! $user_file) {
            return undef;
        } else {
            my $user = load_user($user_file);
            return bless $user, $class;
        }
    }

    # Assert that user file path is defined
    sub assert_values {
        my ($self) = @_;
        if(!$self->{$USER_FILE}) {
            die "No user statistics file specified: $!";
        }
    }

    ## Get or set the user's name (login)
    # Argument: user_name (optional)
    # Return:   user_name
    sub user_name {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$USER_NAME} = $value;
            return $value;
        }
        return $self->{$USER_NAME};
    }

    ## Get a list of files changed, broken
    ## down by additions and removal
    ## see $LINES_ADDED and $LINES_REMOVED
    # Return:   files_changed
    sub files_changed {
        my ($self) = @_;
        return $self->{$FILES_CHANGED};
    }

    ## Get a list of files reviewed, broken
    ## down by additions and removal
    ## see $LINES_ADDED and $LINES_REMOVED
    # Return:   files_changed
    sub files_reviewed {
        my ($self) = @_;
        return $self->{$FILES_REVIEWED};
    }

    ## Add line additions to a file that this user
    ## was responsible for writing
    # Argument: file, line_additions
    # Return:   total_lines_added_to_file
    sub file_changed_add_additions {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, line_additions: $!" if @_ < 3;
        if(!$self->{$FILES_CHANGED}{$file}) {
            my %line_hash = ($LINES_ADDED   => $lines,
                             $LINES_REMOVED => 0 );
            $self->{$FILES_CHANGED}{$file} = \%line_hash;
            return $lines;
        }
        return ($self->{$FILES_CHANGED}{$file}{$LINES_ADDED} += $lines);
    }

    ## Add line additions to a file that this user
    ## was responsible for writing
    # Argument: file, line_additions
    # Return:   total_lines_added
    sub file_changed_get_additions {
        my ($self, $file) = @_;
        die "Arguments: file : $!" if @_ < 2;

        if(! exists $self->{$FILES_CHANGED}{$file}) {
            return 0;
        }

        return $self->{$FILES_CHANGED}{$file}{$LINES_ADDED};
    }

    ## Add line removals to a file that this user
    ## was responsible for writing
    # Argument: file, line_removals
    # Return:   total_lines_removedk
    sub file_changed_add_removals {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, line_additions: $!" if @_ < 3;
        if(!$self->{$FILES_CHANGED}{$file}) {
            my %line_hash = ($LINES_ADDED   => 0,
                             $LINES_REMOVED => $lines );
            $self->{$FILES_CHANGED}{$file} = \%line_hash;
            return $lines;
        }
        return ($self->{$FILES_CHANGED}{$file}{$LINES_REMOVED} += $lines);
    }

    ## Add line removals to a file that this user
    ## was responsible for writing
    # Argument: file, line_removals
    # Return:   total_lines_removed
    sub file_changed_get_removals {
        my ($self, $file) = @_;
        die "Arguments: file : $!" if @_ < 2;

        if(! exists $self->{$FILES_CHANGED}{$file}) {
            return 0;
        }

        return $self->{$FILES_CHANGED}{$file}{$LINES_REMOVED};
    }








    ## Add line additions to a file that this user
    ## was responsible for reviewing
    # Argument: file, line_additions
    # Return:   total_lines_added_to_file
    sub file_reviewed_add_additions {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, line_additions: $!" if @_ < 3;
        if(!$self->{$FILES_REVIEWED}{$file}) {
            my %line_hash = ($LINES_ADDED   => $lines,
                             $LINES_REMOVED => 0 );
            $self->{$FILES_REVIEWED}{$file} = \%line_hash;
            return $lines;
        }
        return ($self->{$FILES_REVIEWED}{$file}{$LINES_ADDED} += $lines);
    }

    ## Add line additions to a file that this user
    ## was responsible for reviewing
    # Argument: file, line_additions
    # Return:   total_lines_added
    sub file_reviewed_get_additions {
        my ($self, $file) = @_;
        die "Arguments: file : $!" if @_ < 2;
        return $self->{$FILES_REVIEWED}{$file}{$LINES_ADDED};
    }

    ## Add line removals to a file that this user
    ## was responsible for reviewing
    # Argument: file, line_removals
    # Return:   total_lines_removed
    sub file_reviewed_add_removals {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, line_additions: $!" if @_ < 3;
        if(!$self->{$FILES_REVIEWED}{$file}) {
            my %line_hash = ($LINES_ADDED   => 0,
                             $LINES_REMOVED => $lines );
            $self->{$FILES_REVIEWED}{$file} = \%line_hash;
            return $lines;
        }
        return ($self->{$FILES_REVIEWED}{$file}{$LINES_REMOVED} += $lines);
    }

    ## Add line removals to a file that this user
    ## was responsible for reviewing
    # Argument: file, line_removals
    # Return:   total_lines_removed
    sub file_reviewed_get_removals {
        my ($self, $file) = @_;
        die "Arguments: file : $!" if @_ < 2;

        if(! exists $self->{$FILES_REVIEWED}{$file}) {
            return 0;
        }

        return $self->{$FILES_REVIEWED}{$file}{$LINES_REMOVED};
    }

    # Write the configuration
    # to the config file - for use
    # when updating or saving configs
    sub write_user {
        my ($user) = @_;
        assert_values $user;

        my $dirname = dirname($user->{$USER_FILE});
        system "mkdir -p $dirname" if $dirname;

        # Open, write, and close file
        open(my $USER, ">$user->{$USER_FILE}")
                or die "Could not write user: $user->{$USER_FILE}";
        print $USER $JSON->encode($user);
        close($USER);
    }

    # Load a user file into a hash,
    # using a new default user if needed
    sub load_user {
        my ($user_file) = @_;

        my $user = make_default_user($user_file);

        # Write defaults at least, if no user present
        if (! -e $user_file) {
            log_debug "Writing default user file";
            write_user($user);
            return $user;
        }
        
        open(my $USER, "<$user_file")
            or die "Could not read user: $user_file";
        my $file_text = read_file($USER);
        close($USER);

        my $loaded_user = $JSON->decode($file_text);

        if(!$loaded_user) {
            log_debug "Writing default user file";
            write_user($user);
            return $user;
        }
        
        # Overlay all loaded values on top of default values.
        # For cases where the stored user is missing a member,
        # this enfoces a default value for that key
        while (my ($key, $value) = each (%{$loaded_user})) {
            $user->{$key} = $value;
        }

        return $user;
    }

    ## Make default user, with mostly empty values
    # Arguments: user_file_path
    # Return: hash reference of default user
    sub make_default_user {
        my ($user_file) = @_;

        # Making empty hash refs hold without any optimization
        # is irritating, as the interpreter will alias empty
        # hash refs without assigning to different variables
        my %empty1 = ();
        my %empty2 = ();
        my %config_hash = ( $USER_FILE       => $user_file,
                            $FILES_REVIEWED  => \%empty2,
                            $FILES_CHANGED   => \%empty1 );

        return \%config_hash;
    }

    sub TO_JSON {
        my ($user) = @_;

        # Remove underlying file store, and
        # don't have a blessing as an object
        my %copy = %{$user};
        delete($copy{$USER_FILE});
        unbless \%copy;

        return \%copy;
    }

    1;
}
