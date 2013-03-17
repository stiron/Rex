#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Cron::Base;

use strict;
use warnings;

use Rex::Logger;
use Rex::Commands;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Commands::Run;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub list {
   my ($self) = @_;
   return @{ $self->{cron} };
}

sub add {
   my ($self, %config) = @_;

   $config{"minute"}        ||= "*",
   $config{"hour"}          ||= "*",
   $config{"day_of_month"}  ||= "*",
   $config{"month"}         ||= "*",
   $config{"day_of_week"}   ||= "*",
   $config{"command"}       ||= "false",


   my $new_cron = sprintf("%s %s %s %s %s %s", $config{"minute"},
                                               $config{"hour"},
                                               $config{"day_of_month"},
                                               $config{"month"},
                                               $config{"day_of_week"},
                                               $config{"command"},
   );

   push(@{ $self->{cron} }, {
      type => "job",
      line => $new_cron,
      cron => \%config,
   });
}

sub delete {
   my ($self, $num) = @_;
   splice(@{ $self->{cron} }, $num, 1);
}

# returns a filename where the new cron is written to
# after that the cronfile must be activated
sub write_cron {
   my ($self) = @_;

   my $rnd_file = "/tmp/" . get_random(8, 'a' .. 'z') . ".tmp";

   my @lines = map { $_ = $_->{line} } @{ $self->{cron} };

   my $fh = file_write $rnd_file;
   $fh->write(join("\n", @lines) . "\n");
   $fh->close;

   return $rnd_file;
}

sub activate_user_cron {
   my ($self, $file, $user) = @_;
   run "crontab -u $user $file";
   unlink $file;
}

sub read_user_cron {
   my ($self, $user) = @_;
   my @lines = run "crontab -u $user -l";
   $self->parse_cron(@lines);
}

sub parse_cron {
   my ($self, @lines) = @_;

   chomp @lines;

   my @cron;

   for my $line (@lines) {

      # comment
      if($line =~ m/^#/) {
         push(@cron, {
            type => "comment",
            line => $line,
         });
      }

      # empty line
      elsif($line =~ m/^\s*$/) {
         push(@cron, {
            type => "empty",
            line => $line,
         });
      }

      # job
      elsif($line =~ m/^(@|\*|[0-9])/) {
         my ($min, $hour, $day, $month, $dow, $cmd) = split(/\s+/, $line, 6);
         push(@cron, {
            type => "job",
            line => $line,
            cron => {
               minute       => $min,
               hour         => $hour,
               day_of_month => $day,
               month        => $month,
               day_of_week  => $dow,
               command      => $cmd,
            },
         });
      }

      elsif($line =~ m/=/) {
         my ($name, $value) = split(/=/, $line, 2);
         $name  =~ s/^\s+//;
         $name  =~ s/\s+$//;
         $value =~ s/^\s+//;
         $value =~ s/\s+$//;

         push(@cron, {
            type  => "env",
            line  => $line,
            name  => $name,
            value => $value,
         });
      }

      else {
         Rex::Logger::debug("Error parsing cron line: $line");
         next;
      }

   }

   $self->{cron} = \@cron;
   return @cron;
}

1;