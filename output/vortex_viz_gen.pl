#!/usr/bin/env perl
#---------------------------------------------------------------------
# vortex_viz_gen.pl
#---------------------------------------------------------------------
#
# Copyright(C) 2011 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASGS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#
#---------------------------------------------------------------------
#
use strict;
use Getopt::Long;
use Math::Trig;
use Date::Pcalc;
use Cwd;
$^W++;

my $dir=".";                        # path to input and output files
my $storm;                          # number, e.g., 05 or 12
my $year;                           # YYYY
my $coldstartdate;                  # YYYYMMDDHH24
my $input="NWS_19_fort.22";         # name of input file
my $nws=19;                         # adcirc met file type
my $output="plot_radii.sh";         # gmt script file
my $hotstartseconds = 0.0;          # default is not hotstart
my $name = "nhcConsensus";          # default track to generate
my $advisorynum="30";
my $pi=3.141592653589793;
my $plot_max = "-99.0";
my $defaultOutputIncrement = "true";# false if user has supplied the output inc
my $output_increment="";        # time in seconds between outputs
# if the NHC issues a special advisory, there may be incomplete lines in the
# hindcast file. This hash will save the most recent complete lines, to fill
# in any missing data.
my %complete_hc_lines = ();
my $nhcName;    # NHC's current storm name (IKE, KATRINA, INVEST, ONE, etc)
my $stormClass; # NHC's current storm classification (TD, TS, HU, IN, etc)
my $frame=0;    # output frame to render, 0 to render all frames
my $myproc=0;   # processor number if we are running in parallel
#
#
GetOptions(
           "dir=s" => \$dir,
           "storm=s" => \$storm,
           "year=s" => \$year,
           "coldstartdate=s" => \$coldstartdate,
           "hotstartseconds=s" => \$hotstartseconds,
           "name=s" => \$name,
           "advisorynum=s" => \$advisorynum,
           "frame=s" => \$frame,
           "myproc=s" => \$myproc,
           "nws=s" => \$nws,
           "plotmax=s" => \$plot_max,
           "outputincrement=s" => \$output_increment
           );
#
# check to see if the output increment was specified
if ( $output_increment ne "" ) {
   $defaultOutputIncrement="false";
}
#
# open NWS19 fort.22 file
unless (open(FORT22,"<$dir/$input")) {
   stderrMessage("ERROR","Failed to open adcirc met file $dir/$input for reading: $!.");
   die;
}
#
# create the gmt script file
unless (open(GMTSCRIPT,">$dir/$output")) {
   stderrMessage("ERROR","Failed to open gmt script file '$dir/$output' for writing: $!.");
   die;
}
#
# add header to gmt script
printf GMTSCRIPT "#!/bin/sh\n";
printf GMTSCRIPT "# generated by vortex_viz_gen.pl to plot wind radii\n";
printf GMTSCRIPT "gmtset PAPER_MEDIA letter+\n"; # the plus means eps
printf GMTSCRIPT "gmtset PAGE_ORIENTATION portrait\n";
#
# read in all the cycle data ... if we have a particular frame of interest,
# we don't know which cycle it will land in
printf GMTSCRIPT "#\n# now plot wind radii\n";
my $cycle_num=0;
my $previous_hour=-1;
my @isotachs_per_cycle;
my @type;
my @time;
my @timesec;
my @vmax;
my @nhc_rmax;
my @B;
my @pc;
my $min_pc = 1015;
my $max_vmax = 40;
my $stormname;
my @tr_speeds;                       # storm translation speed
my @tr_directions;                   # storm translation direction
my @gp_radii;                    # arrow coordinates for radii in gnuplot
my @rmax;
my @unset_gp_radii;
my $arrow_num = 0;
my $label_num = 0;
while (<FORT22>) {
   # break into fields
   my @fields = split(',',$_);
   # grab hour
   my $hour=$fields[5];
   if ( $hour != $previous_hour ) {
      $cycle_num++;
      $arrow_num=5;
      $label_num=2;
      $gp_radii[$cycle_num] = "";
      $unset_gp_radii[$cycle_num] = "";
      $rmax[$cycle_num] = "";
      $isotachs_per_cycle[$cycle_num] = 1;
      $fields[4] =~ /([A-Z]{4})/;
      $type[$cycle_num] = $1;
      $fields[2] =~ /(\d{4})(\d{2})(\d{2})(\d{2})/;
      $time[$cycle_num] = $4."Z ".$2."/".$3."/".$1;
      $fields[5] =~ /(\d+)/;
      $timesec[$cycle_num] = $1 * 3600;
      $fields[8] =~ /(\d+)/;
      $vmax[$cycle_num] = $1;
      if ( $vmax[$cycle_num] > $max_vmax ) {
         $max_vmax = $vmax[$cycle_num];
      }
      $fields[19] =~ /(\d+)/;
      $nhc_rmax[$cycle_num] = $1;
      $fields[38] =~ /(\d{1}+\.\d+)/;
      $B[$cycle_num] = $1;
      $fields[9] =~  /(\d+)/;
      $pc[$cycle_num] = $1;
      if ( $pc[$cycle_num] < $min_pc ) {
         $min_pc = $pc[$cycle_num];
      }
      $fields[27] =~ /([A-Z]+)/;
      $stormname = $1;
      $fields[25] =~ /(\d+)/;
      $tr_directions[$cycle_num] = $1;
      $fields[26] =~ /(\d+)/;
      $tr_speeds[$cycle_num] = $1;
   } else {
      $isotachs_per_cycle[$cycle_num]++;
   }
   $previous_hour = $hour;
   # grab isotach speed
   $fields[11] =~ /(\d+)/;
   my $speed=$1;
   # early in a storm's development (INVEST and prior) the NHC may
   # list the isotach wind speed as zero ... we use 34kt here instead
   # ... just for consistency of display in the plots
   if ( $speed == 0 ) {
      $speed = 34;
   }
   # grab radii and write to file with isotach speed and cycle number for gmt
   my $ne=$fields[13];
   my $se=$fields[14];
   my $sw=$fields[15];
   my $nw=$fields[16];
   my $ne_label_spacing = -$vmax[$cycle_num]/10;
   my $se_label_spacing = $ne_label_spacing * 1.75;
   my $sw_label_spacing = $ne_label_spacing * 2.25;
   my $nw_label_spacing = $ne_label_spacing * 2.75;
   $gp_radii[$cycle_num] .= "set arrow $arrow_num from $ne,$ne_label_spacing to $ne,$speed ls 1\n";
   $gp_radii[$cycle_num] .= "set label $label_num \"NE\" at $ne,$ne_label_spacing center textcolor rgbcolor \"black\"\n";
   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
   $arrow_num++;
   $label_num++;
   $gp_radii[$cycle_num] .= "set arrow $arrow_num from $se,$se_label_spacing to $se,$speed ls 2\n";
   $gp_radii[$cycle_num] .= "set label $label_num \"SE\" at $se,$se_label_spacing center textcolor rgbcolor \"dark-orange\"\n";
   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
   $arrow_num++;
   $label_num++;
   $gp_radii[$cycle_num] .= "set arrow $arrow_num from $sw,$sw_label_spacing to $sw,$speed ls 3\n";
   $gp_radii[$cycle_num] .= "set label $label_num \"SW\" at $sw,$sw_label_spacing center textcolor rgbcolor \"dark-magenta\"\n";
   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
   $arrow_num++;
   $label_num++;
   $gp_radii[$cycle_num] .= "set arrow $arrow_num from $nw,$nw_label_spacing to $nw,$speed ls 4\n";
   $gp_radii[$cycle_num] .= "set label $label_num \"NW\" at $nw,$nw_label_spacing center textcolor rgbcolor \"dark-blue\"\n";
   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
   $arrow_num++;
   $label_num++;
#   my $ne_rmax=$fields[34];
#   my $se_rmax=$fields[35];
#   my $sw_rmax=$fields[36];
#   my $nw_rmax=$fields[37];
#   $rmax[$cycle_num] .= "set arrow $arrow_num from $ne_rmax,$ne_label_spacing to $ne_rmax,$vmax[$cycle_num] ls 8\n";
#   $gp_radii[$cycle_num] .= "set label $label_num \"NE\" at $ne_rmax,$ne_label_spacing center textcolor rgbcolor \"red\"\n";
#   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
#   $arrow_num++;
#   $label_num++;
#   $rmax[$cycle_num] .= "set arrow $arrow_num from $se_rmax,$se_label_spacing to $se_rmax,$vmax[$cycle_num] ls 8\n";
#   $gp_radii[$cycle_num] .= "set label $label_num \"SE\" at $se_rmax,$se_label_spacing center textcolor rgbcolor \"red\"\n";
#   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
#   $arrow_num++;
#   $label_num++;
#   $rmax[$cycle_num] .= "set arrow $arrow_num from $sw_rmax,$sw_label_spacing to $sw_rmax,$vmax[$cycle_num] ls 8\n";
#   $gp_radii[$cycle_num] .= "set label $label_num \"SW\" at $sw_rmax,$sw_label_spacing center textcolor rgbcolor \"red\"\n";
#   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
#   $arrow_num++;
#   $label_num++;
#   $rmax[$cycle_num] .= "set arrow $arrow_num from $nw_rmax,$nw_label_spacing to $nw_rmax,$vmax[$cycle_num] ls 8\n";
#   $gp_radii[$cycle_num] .= "set label $label_num \"NW\" at $nw_rmax,$nw_label_spacing center textcolor rgbcolor \"red\"\n";
#   $unset_gp_radii[$cycle_num] .= "unset arrow $arrow_num\nunset label $label_num\n";
#   $arrow_num++;
#   $label_num++;
#
   my $radii_file_name = "radii_" . $speed . "kt_" . sprintf("cycle%03d",$cycle_num) . ".d";
   unless (open(RADIUSDATA,">$dir/$radii_file_name")) {
      stderrMessage("ERROR","Failed to open gmt script file '$dir/$radii_file_name' for writing: $!.");
      die;
   }
   printf RADIUSDATA "$ne 45\n";
   printf RADIUSDATA "$se 135\n";
   printf RADIUSDATA "$sw 225\n";
   printf RADIUSDATA "$nw 315\n";
   close(RADIUSDATA);
}
#
# now that we know how many isotachs are in each cycle, we can create the
# gmt script code to plot them
my @isotach_speeds = ( 34, 50, 64 );
my @isotach_colors = qw( green purple yellow );
my $extents = "-R0/400/0/360";
my $offset = "-Xa3.5i -Ya2.5i";
my $cycle=0;
my $last_output;
my $sec=0;
if ( $defaultOutputIncrement eq "true" ) {
   $last_output = $cycle_num;
} else {
   $last_output = $timesec[$cycle_num] / $output_increment;
}
for (my $output_num=1; $output_num<=$last_output; $output_num++ ) {
   if ( $defaultOutputIncrement eq "true" ) {
      $cycle=$output_num;
   } else {
      # determine which cycle we are in by the time in seconds
      for ($cycle=1; $cycle<$cycle_num; $cycle++) {
         if ( $sec >= $timesec[$cycle] && $sec < $timesec[$cycle+1] ) {
            last;
         }
      }
   }
   printf GMTSCRIPT "#\n# plots for isotachs of cycle $cycle (time=$sec seconds)\n";
   my $radii_plot_name = sprintf("radii_%03d.ps",$output_num);
   my $radialvp_data_file = sprintf("radialvp_%03d.d",$output_num);
   my $full_circle_data_file = sprintf("full_circle_rmaxes_%03d.d",$output_num);
   my $title = "";
   for (my $isotach=1; $isotach<=$isotachs_per_cycle[$cycle]; $isotach++ ) {
      printf GMTSCRIPT "# plot $isotach_speeds[$isotach-1] kt isotach\n";
      my $radii_file_name = "radii_" . $isotach_speeds[$isotach-1] . "kt_" . sprintf("cycle%03d",$cycle) . ".d";
      my $kontinue="";
      my $append="";
      my $redirect=">";
      if ( $isotach < $isotachs_per_cycle[$cycle]
           || -e $full_circle_data_file || -e $radialvp_data_file ) {
         $kontinue="-K";
      }
      if ( $isotach > 1 ) {
         $append="-O";
         $redirect=">>";
      }
      #
      # info string = [a|f|g]stride[+-phase][unit]
      # ?info segment = info[:"Axis label":][:="prefix":][:,"unit label":]
      # -B[p|s]xinfo[/yinfo[/zinfo]][:."Title":][W|w][E|e][S|s][N|n][Z|z[+]]
      # To specify separate x and y ticks, separate the substrings that apply to the x and y axes with a slash [/]
      # radius increment and annotations
      my $info = "200g100";
      my $segment = ":::,\"nm\":"; # for x axis (r in this case)
      my $xinfo = $info.$segment;
      # azimuth increment and annotations
      $info = "45g45";
      #my $ylabel = "B=$B[$cycle], Vmax=$vmax[$cycle]kt, Pc=$pc[$cycle]mb Vtr=$tr_speeds[$cycle]kt dir=$tr_directions[$cycle]deg";
      my $ylabel = "B=$B[$cycle]";
      if ( $type[$cycle] eq "BEST" ) {
         $ylabel .= ", NHC Rmax=$nhc_rmax[$cycle]nm";
      }
      $segment = ":\"$ylabel\":";
      my $yinfo = $info.$segment;
      # title
      #$title = ":.\"$stormname$advisorynum $type[$cycle] $time[$cycle]\":";
      $title = ":.\"$time[$cycle]\":";
      my $ticks = "-B".$xinfo."/".$yinfo.$title;
      printf GMTSCRIPT "psrose $radii_file_name $kontinue $append -A90 -S2i $extents $offset -G$isotach_colors[$isotach-1] -Wthickest $ticks -L $redirect $radii_plot_name\n";
   }
   # now plot hi-res Rmax results
   if ( -e $full_circle_data_file ) {
      my $kontinue = "";
      if ( -e $radialvp_data_file ) {
         $kontinue = "-K";
      }
      printf GMTSCRIPT "# convert from trigonometric azimuth to compass\n";
      printf GMTSCRIPT "# azimuth and switch radius and azimuth columns\n";
      printf GMTSCRIPT "awk '{ \$2=90-\$2; if (\$2<0) \$2=\$2+360; print \$2\" \"\$1 }' $full_circle_data_file > compass_$full_circle_data_file\n";
      printf GMTSCRIPT "# now plot the fitted Rmax values\n";
      printf GMTSCRIPT "psxy compass_$full_circle_data_file -JP4i -O $kontinue -A -Xa3.5i -Ya2.5i -R0/360/0/400 -Wfat,red  >> $radii_plot_name\n";
   } else {
      stderrMessage("INFO","Could not find $full_circle_data_file.");
      stderrMessage("INFO","The radii will be plotted without Rmax for this output set.");
   }
   if ( -e $radialvp_data_file ) {
      printf GMTSCRIPT "# now plot the line along which we have V(r) and P(r)\n";
      printf GMTSCRIPT "awk '{ print 45\" \"\$1 }' $radialvp_data_file | psxy -JP4i -O -K -A -Xa3.5i -Ya2.5i -R0/360/0/400 -Wfat,black  >> $radii_plot_name\n";
      printf GMTSCRIPT "awk '{ print 315\" \"\$1 }' $radialvp_data_file | psxy -JP4i -O -K -A -Xa3.5i -Ya2.5i -R0/360/0/400 -Wfat,darkorange  >> $radii_plot_name\n";
      printf GMTSCRIPT "awk '{ print 225\" \"\$1 }' $radialvp_data_file | psxy -JP4i -O -K -A -Xa3.5i -Ya2.5i -R0/360/0/400 -Wfat,darkmagenta  >> $radii_plot_name\n";
      printf GMTSCRIPT "awk '{ print 135\" \"\$1 }' $radialvp_data_file | psxy -JP4i -O -K -A -Xa3.5i -Ya2.5i -R0/360/0/400 -Wfat,darkblue  >> $radii_plot_name\n";
   } else {
      stderrMessage("INFO","Could not find $radialvp_data_file.");
      stderrMessage("INFO","The radius plot will not have radial lines in the four quadrants for this output set.");
   }
   # now add some annotations
   printf GMTSCRIPT "pstext -JX4i -O -K -A -Xa3.5i -Ya2.5i -R0/360/0/400 -N << EOF >> $radii_plot_name\n";
   printf GMTSCRIPT "-50 520 40  90  0  BL $stormname$advisorynum $type[$cycle]\n";
   printf GMTSCRIPT "EOF\n";
   if ( $defaultOutputIncrement eq "false" ) {
      $sec += $output_increment;
   }
}
#
# clean up gmt history
printf GMTSCRIPT "# clean up gmt history\n";
printf GMTSCRIPT "rm -f .gmt*\n";
#
# NEW GMT PLOT
# add code to pull out storm center locations
printf GMTSCRIPT "#\n# extract x y locations of unique storm positions to centers.d file\n";
printf GMTSCRIPT "awk 'BEGIN { FS=\",\"; hours=-1; } hours!=\$6 { hours=\$6 ; print -\$8/10\" \"\$7/10 }' $dir/$input > $stormname\_$advisorynum\_centers.d\n";
#
# add code to plot storm center locations on its own background map
printf GMTSCRIPT "#\n# set up x and y limits of plot rounded by 5 deg\n";
# extents of plot: west, east, south, north
printf GMTSCRIPT "limits=`minmax -I5/5 $stormname\_$advisorynum\_centers.d`\n";
# background map
printf GMTSCRIPT "#\n# create background map for storm centers as follows:\n";
printf GMTSCRIPT "# 6in wide, 5 deg Border incr., portrait, gray colored\n";
printf GMTSCRIPT "# land, Verbose output, the plot will be Kontinued, to\n";
printf GMTSCRIPT "# a file centers_[stormname]_[advisory].ps.\n";
printf GMTSCRIPT "pscoast \$limits -JM6i -B5:.\"$stormname $advisorynum\": -P -Ggray  -K > centers_$stormname\_$advisorynum.ps\n";
# crosses
printf GMTSCRIPT "#\n# the cross is made of a vertical line and a horizontal\n";
printf GMTSCRIPT "# line, so psxy has to be called twice.\n";
printf GMTSCRIPT "# The -O indicates that the plot is continued.\n";
printf GMTSCRIPT "psxy -O -K -R -J $stormname\_$advisorynum\_centers.d -S-0.1i -Wthick >> centers_$stormname\_$advisorynum.ps\n";
printf GMTSCRIPT "psxy -R -J -O -K $stormname\_$advisorynum\_centers.d -Sy0.1i -Wthick >> centers_$stormname\_$advisorynum.ps\n";
if ( -e "full_circle_latlon_001.d" ) {
   for (my $cycle=1; $cycle<=$cycle_num; $cycle++ ) {
      my $kontinue="-K";
      if ( $cycle==$cycle_num && !-e "radialvp_latlon_001.d" ) {
         $kontinue="";
      }
      printf GMTSCRIPT sprintf("psxy -R -J -O $kontinue full_circle_latlon_%03d.d -Sp -Wthin >> centers_$stormname\_$advisorynum.ps\n",$cycle);
   }
} else {
   stderrMessage("INFO","Could not find full_circle_latlon_001.d.");
}
if ( -e "radialvp_latlon_001.d" ) {
   for (my $cycle=1; $cycle<=$cycle_num; $cycle++ ) {
      my $kontinue="-K";
      if ( $cycle==$cycle_num ) {
         $kontinue="";
      }
      printf GMTSCRIPT sprintf("psxy -R -J -O $kontinue radialvp_latlon_%03d.d -Sp -Wthin >> centers_$stormname\_$advisorynum.ps\n",$cycle);
   }
} else {
   stderrMessage("INFO","Could not find radialvp_latlon_001.d.");
}
# clean up gmt history
printf GMTSCRIPT "# clean up gmt history\n";
printf GMTSCRIPT "rm -f .gmt*\n";
#
# close shell script file for gmt
close(GMTSCRIPT);
#
#
# G N U P L OT
#
# Now generate a gnuplot script for the V(r) and P(r) line graphs
unless (open(GPSCRIPT,">$dir/radial_v_and_p.gp")) {
   stderrMessage("ERROR","Failed to open gnuplot script file '$dir/radial_v_and_p.gp' for writing: $!.");
   die;
}
#printf GPSCRIPT "set terminal postscript portrait color \"Times-Roman\" 24 size 10,7\n";
printf GPSCRIPT "set terminal postscript portrait color \"Helvetica\" 20 size 10,7\n";
printf GPSCRIPT "set xlabel \"Distance from Center (nm)\"\n";
printf GPSCRIPT "set grid\n";
printf GPSCRIPT "set style line 1 lt 1 lc rgbcolor \"black\" lw 5 pt 1 ps 2\n";
printf GPSCRIPT "set style line 2 lt 1 lc rgbcolor \"dark-orange\" lw 5 pt 2 ps 2\n";
printf GPSCRIPT "set style line 3 lt 1 lc rgbcolor \"dark-magenta\" lw 5 pt 4 ps 2\n";
printf GPSCRIPT "set style line 4 lt 1 lc rgbcolor \"dark-blue\" lw 5 pt 6 ps 2\n";
printf GPSCRIPT "set style line 5 lt 1 lc rgbcolor \"yellow\" lw 5\n";
printf GPSCRIPT "set style line 6 lt 1 lc rgbcolor \"purple\" lw 5\n";
printf GPSCRIPT "set style line 7 lt 1 lc rgbcolor \"green\" lw 5\n";
printf GPSCRIPT "set style line 8 lt 1 lc rgbcolor \"red\" lw 5\n";
printf GPSCRIPT "set title  \"Wind Speed in Each Quadrant\"\n";
printf GPSCRIPT "set key top right\n";
printf GPSCRIPT "set ylabel \"Wind Speed (kt)\"\n";
my $arrow_1_set = 0;
my $arrow_2_set = 0;
$sec=0;
for (my $output_num=1; $output_num<=$last_output; $output_num++ ) {
   # determine which cycle this output time belongs to
   if ( $defaultOutputIncrement eq "true" ) {
      $cycle=$output_num;
   } else {
      # determine which cycle we are in by the time in seconds
      for ($cycle=1; $cycle<$cycle_num; $cycle++) {
         if ( $sec >= $timesec[$cycle] && $sec < $timesec[$cycle+1] ) {
            last;
         }
      }
   }
   my $plot_file_name = sprintf("radialv_%03d.ps",$output_num);
   my $data_file_name = sprintf("radialvp_%03d.d",$output_num);
   # don't write gnuplot code to plot a data file that isn't there
   if ( -e $data_file_name ) {
      if ( $plot_max eq "-99.0" ) {
         $plot_max = $max_vmax + 5;
      }
      printf GPSCRIPT "# now plot wind speed data on properly scaled plot\n";
      printf GPSCRIPT "set yrange [:$plot_max]\n";
      printf GPSCRIPT "set output \"$plot_file_name\"\n";
      if ( $plot_max > 64 ) {
         printf GPSCRIPT "set arrow 1 from 0,64 to 400,64 ls 5 nohead\n";
         $arrow_1_set = 1;
      } else {
         if ( $arrow_1_set == 1 ) {
            printf GPSCRIPT "unset arrow 1\n";
            $arrow_1_set = 0;
         }
      }
      if ( $plot_max > 50 ) {
         printf GPSCRIPT "set arrow 2 from 0,50 to 400,50 ls 6 nohead\n";
         $arrow_2_set = 1;
      } else {
         if ( $arrow_2_set == 1 ) {
            printf GPSCRIPT "unset arrow 2\n";
            $arrow_2_set = 0;
         }
      }
      printf GPSCRIPT "set arrow 3 from 0,34 to 400,34 ls 7 nohead\n";
      printf GPSCRIPT "set arrow 4 from 0,$vmax[$cycle] to 400,$vmax[$cycle] ls 8 nohead\n";
      printf GPSCRIPT "set label 1 \"Vmax\" at -50,$vmax[$cycle] center textcolor rgbcolor \"red\"\n";
      printf GPSCRIPT $gp_radii[$cycle];
      printf GPSCRIPT "plot '$data_file_name' every 60 using 1:2 title \"NE\" with points ls 1,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::15 using 1:3 title \"SE\" with points ls 2,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::30 using 1:4 title \"SW\" with points ls 3,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::45 using 1:5 title \"NW\" with points ls 4,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:2 notitle \"NE\" with lines ls 1,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:3 notitle \"SE\" with lines ls 2,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:4 notitle \"SW\" with lines ls 3,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:5 notitle \"NW\" with lines ls 4,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:6 notitle \"max\" with lines ls 8\n";
      printf GPSCRIPT $unset_gp_radii[$cycle];
   } else {
      stderrMessage("INFO","Could not find $data_file_name.");
      stderrMessage("INFO","Gnuplot code will not be generated for radial velocity data for this output dataset.");
   }
   if ( $defaultOutputIncrement eq "false" ) {
      $sec += $output_increment;
   }
}
printf GPSCRIPT "set title  \"Atmospheric Pressure in Each Quadrant\"\n";
printf GPSCRIPT "set ylabel \"Sea Level Atmospheric Pressure (mbar)\"\n";
printf GPSCRIPT "set key bottom right\n";
printf GPSCRIPT "set yrange[$min_pc:1015]\n";
$sec=0;
for (my $output_num=1; $output_num<=$last_output; $output_num++ ) {
   # determine which cycle this output time belongs to
   if ( $defaultOutputIncrement eq "true" ) {
      $cycle=$output_num;
   } else {
      # determine which cycle we are in by the time in seconds
      for ($cycle=1; $cycle<$cycle_num; $cycle++) {
         if ( $sec >= $timesec[$cycle] && $sec < $timesec[$cycle+1] ) {
            last;
         }
      }
   }
   my $plot_file_name = sprintf("radialp_%03d.ps",$output_num);
   my $data_file_name = sprintf("radialvp_%03d.d",$output_num);
   if ( -e $data_file_name ) {
      printf GPSCRIPT "set output \"$plot_file_name\"\n";
      printf GPSCRIPT "plot '$data_file_name' every 60 using 1:7 title \"NE\" with points ls 1,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::15 using 1:8 title \"SE\" with points ls 2,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::30 using 1:9 title \"SW\" with points ls 3,\\\n";
      printf GPSCRIPT "'$data_file_name' every 60::45 using 1:10 title \"NW\" with points ls 4,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:7 notitle \"NE\" with lines ls 1,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:8 notitle \"SE\" with lines ls 2,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:9 notitle \"SW\" with lines ls 3,\\\n";
      printf GPSCRIPT "'$data_file_name' using 1:10 notitle \"NW\" with lines ls 4\n";
   } else {
      stderrMessage("INFO","Could not find $data_file_name.");
      stderrMessage("INFO","Gnuplot code will not be generated for radial barometric pressure data for this output dataset.");
   }
   if ( $defaultOutputIncrement eq "false" ) {
      $sec += $output_increment;
   }
}
close(GPSCRIPT);
#
# generate data to show solution process for determination of Rmax
# equation containing Coriolis forces
# B=1.0, Vmax=45kt, Pc = 979mb, Vtr = 17kt, dir=23deg, Ir = 220nm, Vr=34kt
#
# open data file for Vh with coriolis
unless (open(WITHCORIOLIS,">withCoriolis.d")) {
   stderrMessage("ERROR","Failed to open withCoriolis.d for writing: $!.");
   die;
}
# open data file for Vh without coriolis
unless (open(NOCORIOLIS,">noCoriolis.d")) {
   stderrMessage("ERROR","Failed to open noCoriolis.d for writing: $!.");
   die;
}
my $windReduction = 0.8924;
my $testB = 1.0;
my $Vmax = 45;
my $Pc = 979;
my $Vtr = 17;
my $dir = 23;
my $Ir = 220;
my $Vr = 34;
my $cLat = 44.2;
my $cori = 2*sin(deg2rad($cLat))*2*$pi/86164.2;
$Vmax = ($Vmax - $Vtr) / $windReduction;
for (my $r=1; $r<400; $r++ ) {
   printf WITHCORIOLIS "$r ";
   printf NOCORIOLIS "$r ";
   for (my $rmx=10; $rmx<400; $rmx+=10 ) {
      my $Vh = 1/0.5144*(sqrt(
         ($Vmax*0.51444)**2 * ($rmx/$r)**$testB * exp(1-($rmx/$r)**$testB)
            + (1852*$r*$cori/2)**2) - 1852*$r*$cori/2);
      $Vh = ($Vh*$windReduction) + $Vtr;
      printf WITHCORIOLIS " $Vh";
      $Vh = 1/0.5144*(sqrt(
         ($Vmax*0.51444)**2 * ($rmx/$r)**$testB * exp(1-($rmx/$r)**$testB)));
      $Vh = ($Vh*$windReduction) + $Vtr;
      printf NOCORIOLIS " $Vh";
   }
   printf WITHCORIOLIS "\n";
   printf NOCORIOLIS "\n";
}
close(WITHCORIOLIS);
close(NOCORIOLIS);
#
sub stderrMessage () {
   my $level = shift;
   my $message = shift;
   my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   (my $second, my $minute, my $hour, my $dayOfMonth, my $month, my $yearOffset, my $dayOfWeek, my $dayOfYear, my $daylightSavings) = localtime();
   my $year = 1900 + $yearOffset;
   my $hms = sprintf("%02d:%02d:%02d",$hour, $minute, $second);
   my $theTime = "[$year-$months[$month]-$dayOfMonth-T$hms]";
   printf STDERR "$theTime $level: vortex_viz_gen.pl: $message\n";
   if ($level eq "ERROR") {
      sleep 60
   }
}

