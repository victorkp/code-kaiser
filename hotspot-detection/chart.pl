#!/usr/bin/perl
{
    use GD::Graph::Map;
    use GD::Graph::pie;
    use Storable;
    use strict;
    use warnings;

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(chart_hotspot_from_file chart_hotspot_from_struct);

    ## Make a chart in high and low resolution
    ## as well as HTML map for code hotspot files,
    ## using the hash reference returned from
    ## CodeKaiser::DiffProcessor->process_diffs
    # Arguments: save-file, output-directory
    sub chart_hotspot_from_struct(\%$) {
        my ($files_ref, $output_dir) = @_;
        my %files = %{$files_ref};

        # Get filenames sorted by hightest to lowest hotspot_score
        my @labels = sort { $files{$b}{hotspot_score} 
                              <=> $files{$a}{hotspot_score} } keys %files;

        # Push scores to array, in order of highest->lowest scoring files,
        # also write data to easy-to-consume CSV file (for debugging, or download)
        my @scores;
        open CSV, ">$output_dir/hotspots.csv" or die "Couldn't open output CSV file: $!";
        foreach my $f (@labels) {
            # TODO does sqrt of score scale ideally for a chart?
            push(@scores, sqrt($files{$f}{hotspot_score}));
            print CSV $f . " : ". $files{$f}{hotspot_score} . "\r\n";
        }
        close CSV;

        my @CHART_COLORS = ['#dF0000', '#e04000', '#e07500', '#e0a800', '#e0e000', '#a8e000'];
        my @CHART_COLORS_SHADOWS = ['#dF0000', '#e04000', '#e07500', '#e0a800', '#e0e000', '#a8e000'];
        my $chart = new GD::Graph::pie(3200, 2400);
        $chart->set(title => 'Recent Code Hotspots') or die $chart->error;
        $chart->set(dclrs => @CHART_COLORS);
        $chart->set(transparent => 0);
        $chart->set_title_font('fonts/arial.ttf', 24*4);
        $chart->set_label_font('fonts/arial.ttf', 16*4);
        $chart->set_value_font('fonts/arial.ttf', 16*4);

        my $FILE_COUNT_IN_CHART = 6;
        my $top_index  = (scalar(@labels) < $FILE_COUNT_IN_CHART) ? (scalar(@labels)) : ($FILE_COUNT_IN_CHART);
        my @top_files  = @labels[0 .. $top_index];

        my @top_files_shortened;
        for(my $i = 0; $i < $top_index; $i++) {
            push(@top_files_shortened, substr($labels[$i], rindex($labels[$i], '/') + 1));
        }
        my @top_scores = @scores[0 .. $top_index];

        my @data = ([@top_files_shortened], [@top_scores]);

        open OUT, ">$output_dir/hotspots-large.png" or die "Couldn't open output file: $!";
        binmode(OUT);
        print OUT $chart->plot(\@data)->png;
        close OUT;

        # Resample image down (dumb antialiasing)
        my $image_large = new GD::Image("$output_dir/hotspots-large.png");
        my $image_final = new GD::Image(800, 600);
        $image_final->copyResampled($image_large, 0, 0, 0, 0, 800, 600, 3200, 2400);
        open OUT, ">$output_dir/hotspots.png" or die "Couldn't open output file: $!";
        binmode(OUT);
        print OUT $image_final->png;
        close OUT;

        # Create HTML Map for hover-over information
        $chart = new GD::Graph::pie(800, 600); # Use smaller scale for HTML map
        my $html_map = new GD::Graph::Map($chart, newWindow => 1);
        $html_map->set(info => "%x is %.1p% hot");
        $html_map->set(mapName => "hotspot_map");
        $html_map->set(noImgMarkup => 1);
        open HTML, ">$output_dir/hotspots.html" or die "Couldn't open HTML output file: $!";
        print HTML "<!DOCTYPE html><html><body>\n";
        print HTML $html_map->imagemap("hotspots.png", \@data);
        print HTML "<Img UseMap=#hotspot_map Src=\"hotspots.png\" border=0 Height=600 Width=800>\n";
        print HTML "</body></html>\n";
        close HTML;
    }

    ## Make a chart in high and low resolution
    ## as well as HTML map for code hotspot files,
    ## using a save-file from CodeKaiser::DiffProcessor
    # Arguments: save-file, output-directory
    sub chart_hotspot_from_file($$) {
        # Require input file
        scalar(@_) == 2 or die "Required parameters: <save-file> <output-dir>\n";

        my ($save_file, $output_dir) = @_;

        # Retrieve the 'files' structure which contains hotspot scores
        my $last_save_hash = retrieve($save_file);
        my $files          = $$last_save_hash{files};

        chart_hotspot_from_struct($files, $output_dir);
    }

    1;
}
