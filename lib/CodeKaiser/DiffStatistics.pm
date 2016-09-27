#!/bin/perl
{
    package CodeKaiser::DiffStatistics;
    use strict;
    use warnings;
     
    use File::Spec;
    use File::Basename;
    use File::Slurp;
    use Scalar::Util;
    use Data::Dumper;
    use JSON;
    use Data::Structure::Util qw( unbless );

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(new
                      diff_number
                      diff_sha
                      get_total_additions
                      get_total_removals
                      get_all_additions
                      get_all_removals
                      add_additions
                      add_removals
                      clear_additions_and_removals
                      write_file
                      TO_JSON
                     );

    my $JSON = JSON->new->allow_blessed->convert_blessed->pretty;

    # Diff file path key
    my  $DIFF_FILE         = 'diff_file';

    # Corresponds to PR number
    my  $DIFF_NUMBER       = 'diff_number';

    # Pull Request's latest commit SHA
    my  $DIFF_SHA          = 'diff_sha';

    # Sum of all lines added (in DIFF_ADDITIONS)
    my  $TOTAL_ADDITIONS   = 'total_additions';

    # Sum of all lines removed (in DIFF_REMOVALS)
    my  $TOTAL_REMOVALS    = 'total_removals';

    # Hash of {file} => lines_added
    my  $DIFF_ADDITIONS    = 'line_additions';

    # Hash of {file} => lines_removed
    my  $DIFF_REMOVALS     =  'line_removals';

    ## Load a pull rules configuration file,
    ## creating a configuration file with defaults
    ## if none exists at specified path
    # Expects { diff_stat_file => <filename> }
    sub new($) {
        my ($class, %args) = @_;

        my $diff_file = $args{diff_stat_file};
        if(! $diff_file) {
            return undef;
        } else {
            my $diff = load_diff($diff_file);
            return bless $diff, $class;
        }
    }

    # Assert that diff file path is defined
    sub assert_values {
        my ($self) = @_;
        if(!$self->{$DIFF_FILE}) {
            die "No diff file specified: $!";
        }
    }

    ## Get or set the diff number (PR number)
    # Argument: diff_number (optional)
    # Return:   diff_number
    sub diff_number {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$DIFF_NUMBER} = $value;
            return $value;
        }
        return $self->{$DIFF_NUMBER};
    }

    ## Get or set the diff's commit SHA for the HEAD branch
    # Argument: diff_ha (optional)
    # Return:   diff_ha
    sub diff_sha {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if($value =~ /^[0-9a-fA-F]+$/) {           
                $self->{$DIFF_SHA} = $value;
                return $value;
            } else {
                die 'Bad argument, expecting hex string for commit SHA';
            }
        }
        return $self->{$DIFF_SHA};
    }

    ## Clears all additions and removals 
    sub clear_additions_and_removals {
        my ($self) = @_;
        $self->{$DIFF_ADDITIONS}  = {};
        $self->{$DIFF_REMOVALS}   = {};
        $self->{$TOTAL_ADDITIONS} = 0;
        $self->{$TOTAL_REMOVALS}  = 0;
    }

    ## Get the total number of lines that were added by this diff
    sub get_total_additions {
        my ($self) = @_;
        return $self->{$TOTAL_ADDITIONS};
    }

    ## Get the total number of lines that were removed by this diff
    sub get_total_removals {
        my ($self) = @_;
        return $self->{$TOTAL_REMOVALS};
    }

    ## Add line additions to a file 
    ## that this diff includes
    # Argument: file, line_additions
    # Return:   total_lines_added_to_file
    sub add_additions {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, lines_added $!" if @_ < 3;

        $self->{$TOTAL_ADDITIONS} += $lines;

        if(! exists($self->{$DIFF_ADDITIONS}{$file})) {
            $self->{$DIFF_ADDITIONS}{$file} = $lines;
            return $lines;
        }

        return $self->{$DIFF_ADDITIONS}{$file} += $lines;
    }

    ## Add line additions to a file 
    ## that this diff includes
    # Argument: file, line_removals
    # Return:   total_lines_removed_from_file
    sub add_removals {
        my ($self, $file, $lines) = @_;
        die "Arguments: file, lines_removed $!" if @_ < 3;

        $self->{$TOTAL_REMOVALS} += $lines;

        if(! exists($self->{$DIFF_REMOVALS}{$file})) {
            $self->{$DIFF_REMOVALS}{$file} = $lines;
            return $lines;
        }

        return $self->{$DIFF_REMOVALS}{$file} += $lines;
    }

    ## Get a hash of file => lines
    ## hash for all additions by this diff
    ## DO NOT MUTATE the returned hash
    sub get_all_additions {
        my ($self) = @_;
        return $self->{$DIFF_ADDITIONS};
    }

    ## Get a hash of file => lines
    ## hash for all removals by this diff
    ## DO NOT MUTATE the returned hash
    sub get_all_removals {
        my ($self) = @_;
        return $self->{$DIFF_REMOVALS};
    }

    # Write the configuration
    # to the config file - for use
    # when updating or saving configs
    sub write_file {
        my ($diff) = @_;
        assert_values $diff;

        my $dirname = dirname($diff->{$DIFF_FILE});
        system "mkdir -p $dirname" if $dirname;

        # Open, write, and close file
        open(my $DIFF, ">$diff->{$DIFF_FILE}")
                or die "Could not write diff statistics: $diff->{$DIFF_FILE}";
        print $DIFF $JSON->encode($diff);
        close($DIFF);
    }

    # Load a diff file into a hash,
    # using a new default diff if needed
    sub load_diff {
        my ($diff_file) = @_;

        my $diff = make_default_diff($diff_file);

        # Write defaults at least, if no diff present
        if (! -e $diff_file) {
            log_debug "Writing default diff file";
            write_file($diff);
            return $diff;
        }
        
        open(my $DIFF, "<$diff_file")
            or die "Could not read diff: $diff_file";
        my $file_text = read_file($DIFF);
        close($DIFF);

        my $loaded_diff = $JSON->decode($file_text);

        if(!$loaded_diff) {
            log_debug "Writing default diff file";
            write_file($diff);
            return $diff;
        }
        
        # Overlay all loaded values on top of default values.
        # For cases where the stored diff is missing a member,
        # this enfoces a default value for that key
        while (my ($key, $value) = each (%{$loaded_diff})) {
            $diff->{$key} = $value;
        }

        return $diff;
    }

    ## Make default diff, with mostly empty values
    # Arguments: diff_file_path
    # Return: hash reference of default diff
    sub make_default_diff {
        my ($diff_file) = @_;

        my %empty1;
        my %empty2;

        my %diff_hash = ( $DIFF_FILE        => $diff_file,
                          $DIFF_NUMBER      => '0',
                          $DIFF_SHA         => '',
                          $DIFF_ADDITIONS   => \%empty1,
                          $DIFF_REMOVALS    => \%empty2 );

        return \%diff_hash;
    }

    sub TO_JSON {
        my ($diff) = @_;

        # Remove underlying file store, and
        # don't have a blessing as an object
        my %copy = %{$diff};
        delete($copy{$DIFF_FILE});
        unbless \%copy;

        return \%copy;
    }

    1;
}
