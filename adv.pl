#!/usr/bin/perl -w
# Copyright (c) 2008 Alex Curtis

use strict;
our %locations;  # Description of locations, keyed by location name
our %objects;  # Object descriptions, keyed by object short name
our %exits; # Names of locations reached by exits. Keyed by location.direction
our %exitingtext; # Text to read out when the user takes an exit
our $current_loc = ""; # String of name of current location. Used as key to hashes.
our %obj_locations; # Location name for each object, or "local" if carried by player.
our %locationobjects; # Arrays of objects at each location, keyed by location
our @visited_locations = (); # Array of the 5 most recently visited locations
our %objspecifiers; # "a", "an", "some", etc..., keyed by object name
our %locspecifiers; # "at the", "outside the", "crouching in the", etc..., keyed by location name
our %objgetability; # "" means you can get it. "replenishes" means you get it and it stays in the room. "You can't" or any other message means you can't get it.
our %objvisibility; # "visible" means it's listed at the end of the room description. "apparent" means it's been mentioned in the room description (e.g. part of the scenery).
our %objsynonyms; # Hash keyed by object's alternative name, giving name used by the game, e.g. "house"->"building".
our %verbreqobj; # Hash keyed by verbs giving required object to use that verb. E.g. v:dig:spade:You need something to dig with.
our %verbreqobjphrase; # Hash keyed by verbs giving phrase to say if required object not carried E.g. v:dig:spade:You need something to dig with.
our %activities; # Hash keyed by verb:location giving array of arrays describing activities. E.g. a:unlock:front door:key:door:front door!=locked:It isn't locked.:state front door=closed
our %states; # Hash of variables, keyed by variable name, containing variable's value
my $debug = 0; # Level of debug output. Higher number means more debug.

## Evaluate a state expression
sub TestState
{
  my $result = 0;
  my $expr = shift;

  # Noddy version for now
  if( $expr eq "" )
  {
    $result = 1;
  }
  elsif( $expr =~ m/(.*)==(.*)/ )
  {
    if( exists $states{$1} and $states{$1} eq $2 )
    {
      $result = 1;
    }
  }
  elsif( $expr =~ m/(.*)!=(.*)/ )
  {
    if( exists $states{$1} and $states{$1} ne $2 )
    {
      $result = 1;
    }
  }
  return $result;
}

## Test and act on any activities for this verb and location
sub DoActivity
{
  my $result = 0;
  my $action_location = shift;
  my $scope = shift;
  if( exists $activities{ $action_location } )
  {
    my @act_arr_arr = @{ $activities{ $action_location } };
    for my $act_arr_s (@act_arr_arr)
    {
      my @act_arr = @$act_arr_s;
      my $activity_object = $act_arr[0];
      my $activity_scope = $act_arr[1];
      my $activity_reqstate = $act_arr[2];
      my $activity_phrase = $act_arr[3];
      my $activity_commands = $act_arr[4];

  if( $debug==1 ) {print "#    possible activity:\r\n";}
  if( $debug==1 ) {print "#    a:$action_location:$activity_object:$activity_scope:$activity_reqstate:$activity_phrase:$activity_commands\r\n";}
      if( $activity_scope eq $scope ) # scope may be "" but then so should activity_scope
      {
  if( $debug==1 ) {print "#    scope ok - trying object $activity_object\n";}
        if( $activity_object eq "" or $obj_locations{$activity_object} eq "local" )
        {
  if( $debug==1 ) {print "#    object ok - trying state $activity_reqstate\n";}
          if( TestState( $activity_reqstate ) != 0 )
          {
            print "$activity_phrase\n";
if( $debug==1 ) {print "#    running cmds \"$activity_commands\"\n";}
            if( $activity_commands ne "" )
            {
              my @commands = split ";", $activity_commands;
              for my $command ( @commands )
              {
  if( $debug==1 ) {print "#    executing cmd $command\n";}
                ExecuteCommand( $command );
              }
            }

            $result = 1;
            last; # Stop once an activity matches.
          }
        }
      }
    }

  }
  return $result;
}
## Translate an object's location from location_a to location_b
sub TranslateObject
{
    my $object = shift;
    my $location_a = shift;
    my $location_b = shift;

    if( $debug>=5 ) {print "#    Translate $object from $location_a to $location_b\n";}

    $obj_locations{$object} = $location_b;

    #remove @{ $locationobjects{$current_loc} }, $object;
    if( exists $locationobjects{$location_a}  ) # Won't exist if location_a is "nowhere"
    {
      my $num = @{ $locationobjects{$location_a} };
      for( my $i = 0; $i < $num; $i++)
      {
          my $lineobj = @{ $locationobjects{$location_a} }[$i];
          if( $debug>=5 ) {print "#    compare \"$lineobj\" and \"$object\" at $i\n";}
          if( $lineobj eq $object )
          {
              splice @{ $locationobjects{$location_a} }, $i, 1;
              $i = $num;
              if( $debug>=5 ) {print "#    match at $i\n";}
          }
      }
      if( $debug>=5 ) {print "#     compare $num\n";}
    }

    push @{ $locationobjects{$location_b} }, $object;
}

sub LineDump
{
    my $location = shift;
    if( defined $locspecifiers{$location} )
    {
      print "You are $locspecifiers{$location} $location.\n";
    }
    else
    {
      print "You're location is $location.\n";
    }
}

sub ShowObjects
{
    my $location = shift;
    my $form = shift; # 0 = as if for room, 1 = as if for inventory.

    my $olist = "";
    my $count = 0;
    if( exists( $locationobjects{$location} ) )
    {
        my $num_objs = @{ $locationobjects{$location} };
        foreach my $o (@{ $locationobjects{$location} })
        {
            if( $objvisibility{$o} eq "visible" )
            {
                my $my_o = $o;
                if( length $olist > 0 )
                {
                    if( $form == 0 )
                    {
                        if( $count < $num_objs-1 )
                        {
                            $olist .= ", ";
                        }
                        else
                        {
                            $olist .= " and ";
                        }
                    }
                }
                if( defined $objspecifiers{$o} and $objspecifiers{$o} ne "" )
                {
                    $my_o = $objspecifiers{$o}. " " . $my_o
                }
                $count++;
                if( $form == 1 )
                {
                    $my_o = "  " . $my_o;
                }
                $olist .= $my_o;
                if( $form == 1 )
                {
                    $olist .= "\n";
                }
            }
        }
    }
    if( $count >  0 )
    {
        if( $form == 0 )
        {
            print "You can see $olist here.\n";
        }
        else
        {
            print "You are carrying:\n$olist";
        }
    }
}

## Write test file
sub WriteFile
{
    my $filename = shift;
    print "Writing test file \"$filename\"\n";

    open( FH, ">".$filename ) or die("Can't open file $filename for writing.\n");
    print FH "#test file for adv.pl v.0.01\n";
    foreach my $location( keys %locations )
    {
        print FH "l:$location:$locspecifiers{$location}:$locations{$location}\n";
    }
    foreach my $obj(keys %objects)
    {
        print FH "o:$obj:$obj_locations{$obj}:$objspecifiers{$obj}:$objgetability{$obj}:$objvisibility{$obj}:$objects{$obj}\n";
    }
    foreach my $objsynonym(keys %objsynonyms)
    {
        print FH "s:$objsynonym:$objsynonyms{$objsynonym}\n";
    }
    foreach my $exit(keys %exits)
    {
        print FH "x:$exit:$exits{$exit}:$exitingtext{$exit}\n";
    }
    foreach my $verb(keys %verbreqobj)
    {
        print FH "v:$verb:$verbreqobj{$verb}:$verbreqobjphrase{$verb}\n";
    }
    for my $activity_key ( keys %activities ) {
      my @act_arr_arr = @{ $activities{$activity_key} };
        for my $activity ( @act_arr_arr )
        {
          my @actarr = @$activity;
          print FH "a:$actarr[0]:$actarr[1]:$actarr[2]:$actarr[3]:$actarr[4]\n";
        }
    }
    foreach my $state(keys %states)
    {
        print FH "s:$state:$states{$state}\n";
    }

    close( FH );
}


sub Transition
{
    my ( $dirn, $sdirn) = @_;
    if( defined $exits{ $current_loc . "." . $sdirn } )
    {
        if( defined $exitingtext{ $current_loc . "." . $sdirn } )
        {
          print $exitingtext{ $current_loc . "." . $sdirn };
        }
        else
        {
          print "You travel " . $dirn . ".\n";
        }
        $current_loc = $exits{ $current_loc . "." . $sdirn };
    }
    else
    {
        print "You cannot go $dirn.\n";
    }

    return $current_loc;
}


sub Chk
{
    my $scope = shift;
    $scope =~ tr/A-Za-z/N-ZA-Mn-za-m/;
    return $scope;
}

sub DirnConvert
{
    my $dirn = shift;
    if( $dirn eq "n" )
    {
        return 1;
    }
    elsif( $dirn eq "s" )
    {
        return 2;
    }
    elsif( $dirn eq "e" )
    {
        return 3;
    }
    elsif( $dirn eq "w" )
    {
        return 4;
    }
    elsif( $dirn eq "ne" )
    {
        return 5;
    }
    elsif( $dirn eq "nw" )
    {
        return 6;
    }
    elsif( $dirn eq "se" )
    {
        return 7;
    }
    elsif( $dirn eq "sw" )
    {
        return 8;
    }
    elsif( $dirn eq "u" )
    {
        return 9;
    }
    elsif( $dirn eq "d" )
    {
        return 10;
    }
    return 0;
}

sub DirnSort
{
    return DirnConvert( $a ) - DirnConvert( $b );
    #return -1;
}

sub ShowExits
{
    my @exit_list = ();
    foreach my $exit(keys %exits)
    {
        if( $exit =~ m/$current_loc\.(.+)$/ )
        {
            push @exit_list, $1;
        }
    }
    @exit_list = sort DirnSort @exit_list;
    if( @exit_list > 0 )
    {
        print "Exits lead " . (join ",", @exit_list) . ".\n";
    }
    else
    {
        print "There are no obvious exits from here.\n";
    }
}

sub ShowRoom
{
  if( defined $locations{$current_loc} )
  {
    print "$locations{$current_loc}\n";
  }
  else
  {
    print "ERROR: No description for $current_loc.\n";
  }
}

sub Visited
{
    my $location = shift;
    foreach my $recently_visited (@visited_locations)
    {
        if( $recently_visited eq $location )
        {
            return 1;
        }
    }
    return 0;
}

# Prints the current adventure data to stdout.
sub DumpFile
{
    print "LINES:\n";
    foreach my $location(keys %locations)
    {
        print "$location:$locations{$location}\n";
    }
    print "OBJECTS:\n";
    foreach my $obj(keys %objects)
    {
        print "$obj:$obj_locations{$obj}:$objspecifiers{$obj}:$objgetability{$obj}:$objects{$obj}\n";
    }
    print "EXITS:\n";
    foreach my $exit(keys %exits)
    {
        print "$exit:$exits{$exit}:$exitingtext{$exit}\n";
    }
    print "LINEOBJS:\n";
    for my $lo ( keys %locationobjects ) {
        print "$lo: @{ $locationobjects{$lo} }\n";
    }
    print "VERBREQOBJ:\n";
    for my $verb ( keys %verbreqobj ) {
        print "$verb:$verbreqobj{$verb}:$verbreqobjphrase{$verb}\n";
    }
    print "ACTIONS:\n";
    for my $activity_key ( keys %activities ) {
      my @act_arr_arr = @{ $activities{$activity_key} };
        for my $activity ( @act_arr_arr )
        {
          my @actarr = @$activity;
          print "$actarr[0]:$actarr[1]:$actarr[2]:$actarr[3]:$actarr[4]\n";
        }
    }
    print "STATES:\n";
    for my $state ( keys %states ) {
        print "$state:$states{$state}\n";
    }
}
sub LoadFile
{
    my $filename = shift;

    # Read test file
    open( FH, $filename ) or die("Can't open file $filename.\n");

    ## Read file into buffer
   # print "Reading test file $filename\n";
    while( <FH> ) {
        if( m/^l:((\w|\s)+):((\w|\s)+):(.*)$/ )
        {
            if( defined $locations{$1} )
            {
                print "WARNING: location $1 already defined!\n";
            }
            $locspecifiers{$1} = $3;
            $locations{$1} = $5;
            if( $current_loc eq "" )
            {
                $current_loc = $1; # start at first room described in file
            }

        }
        elsif( m/^o:([^:]+):([^:]+):([^:]+):([^:]*):([^:]+):(.*)$/ )
        {
            if( defined $objects{$1} )
            {
                print "WARNING: object $1 already defined!\n";
            }
            $objects{$1} = $6;
            $obj_locations{$1} = $2;
            $objspecifiers{$1} = $3;
            $objgetability{$1} = $4;
            $objvisibility{$1} = $5;
            push @{ $locationobjects{$2} }, $1;
        }
        elsif( m/^s:([^:]+):(.*)$/ )
        {
            if( defined $objsynonyms{$1} )
            {
                print "WARNING: synonym $1 already defined!\n";
            }
            $objsynonyms{$1} = $2;
        }
        elsif( m/^x:((\w|\s)+\.\w+):(.*)$/ )
        {
            if( defined $exits{$1} )
            {
                print "WARNING: exit for $1 already defined!\n";
            }
            $exits{$1} = $3;
            $exitingtext{$1} = "";
        }
        elsif( m/^x:((\w|\s)+\.\w+):(.*):(.*)$/ )
        {
            if( defined $exits{$1} )
            {
                print "WARNING: exit for $1 already defined!\n";
            }
            $exits{$1} = $3;
            $exitingtext{$1} = $4;
        }
        elsif( m/^#/ )
        {
            # a comment in the tst file.
        }
        elsif( m/^v:([^:]+):([^:]+):(.*)$/ )
        {
            if( defined $verbreqobj{$1} )
            {
                print "WARNING: verb $1 already defined!\n";
            }
            $verbreqobj{$1} = $2;
            $verbreqobjphrase{$1} = $3;
        }
        elsif( m/^a:([^:]+):([^:]*):([^:]*):([^:]*):([^:]*):([^:]+):(.*)$/ )
        {
##a=activity -> verb:location:object:required state:what happens:object to add to location:opject to add to inventory:new state
            my $activity_location = "$1:$2";
            my $activity_object = $3;
            my $activity_scope = $4;
            my $activity_reqstate = $5;
            my $activity_phrase = $6;
            my $activity_commands = $7;
            my @activity = ($activity_object,$activity_scope,$activity_reqstate,$activity_phrase,$activity_commands);
            my @new_arr = ();
            if( exists $activities{$activity_location} )
            {
              @new_arr = @{$activities{$activity_location}}; # TODO: Use reference instead of copying array
            }
            push @new_arr, [ @activity ];
            $activities{$activity_location} =  [ @new_arr ];
        }
        elsif( m/^s:([^:]+):(.*)$/ )
        {
            if( defined $states{$1} )
            {
                print "WARNING: state $1 already defined!\n";
            }
            $states{$1} = $2;
        }
        elsif( !m/^\s*$/ )
        {
            print "WARNING: unparsed line: $_\n";
        }
    }
    close( FH );

    DumpFile(); # Prints the current adventure data to stdout.
}

##########################################################
##########################################################
##########################################################
##########################################################

if( scalar @ARGV != 1 )
{
    die("usage: adv.pl <adv file>\n");
}

sub ExecuteCommand
{
  my $scope = "";

  my $command = shift;
    my $sp_pos = index ($command, ' ');
    if( $sp_pos >= 0 )
    {
        $scope = substr ($command, $sp_pos+1);
        $command = substr ($command, 0, $sp_pos);
    }
    if( $debug>=5 ) {print "#    command is \"$command\"\n";}
    if( $debug>=4 ) {print "#    scope is \"$scope\"\n";}

    my $command_processed_ok = 0;
    # Try adventure defined verbs and actions
    # First see if verb has any pre-requisites, e.g. 'dig' needs 'spade' to be in player's posession.
    my $allowed = 1;
    if( exists $verbreqobj{$command} )
    {
        my $required_obj = $verbreqobj{$command};
        if( $obj_locations{ $required_obj } ne "local" )
        {
            print "$verbreqobjphrase{$command}\n";
            $allowed = 0;
        }
    }
    # Now see if there are any actions for the verb.
    if( $allowed != 0 )
    {
      my $action_location = "$command:$current_loc";
      my $action_anywhere = "$command:";
      if( $debug>=4 ) {print "#    searching actions for $action_location\n";}

      if( DoActivity($action_location, $scope) )
      {
        $command_processed_ok = 1;
      }
      elsif( DoActivity($action_anywhere, $scope) )
      {
        $command_processed_ok = 1;
      }

    }
    if( $debug>=4 ) {print "#    ok=$command_processed_ok\n";}

    if( $command_processed_ok == 0 )
    {
      # now try built in commands
      if( $command eq "help" or $command eq "verbs" or $command eq "words" )
      {
        print "I understand:\n";
        print "help|verbs|words,quit|q,look,exits,dump,n|north,s|south,e|east,w|west\n";
	print "Type INSTRUCTIONS for more help.\n";
      }
      elsif( $command eq "instructions" )
      {
        print "Here is a list of the built in commands I understand. I may understand more than this in certain locations.\n";
	print "HELP\nPrints a short list of the commands I know.\n\n";
	print "VERBS\nSee HELP.\n\n";
	print "WORDS\nSee HELP.\n\n";
        print "QUIT, Q\nExits the game.\n\n";
	print "LOOK\nDescribes your current location.\n\n";
	print "EXITS\nLists the available directions of travel from your current location.\n\n";
        print "DUMP\n(God command) Prints the current adventure data to stdout.\n\n";
      }
      elsif( $command eq "quit" or $command eq "q" )
      {
          print "Goodbye.\n";
          exit(0);
      }
      elsif( $command eq "look" )
      {
          ShowRoom();
          ShowExits();
      }
      elsif( $command eq "exits" )
      {
          ShowExits();
      }
      elsif( $command eq "dump" )
      {
          DumpFile(); # Prints the current adventure data to stdout.
      }
      elsif( $command eq "n" or $command eq "north" )
      {
          Transition( "north", "n" );
      }
      elsif( $command eq "s" or $command eq "south" )
      {
          Transition( "south", "s" );
      }
      elsif( $command eq "e" or $command eq "east" )
      {
          Transition( "east", "e" );
      }
      elsif( $command eq "w" or $command eq "west" )
      {
          Transition( "west", "w" );
      }
      elsif( $command eq "u" or $command eq "up" )
      {
          Transition( "up", "u" );
      }
      elsif( $command eq "d" or $command eq "down" )
      {
          Transition( "down", "d" );
      }
      elsif( $command eq "ne" or $command eq "northeast" )
      {
          Transition( "northeast", "ne" );
      }
      elsif( $command eq "nw" or $command eq "northwest" )
      {
          Transition( "northwest", "nw" );
      }
      elsif( $command eq "se" or $command eq "southeast" )
      {
          Transition( "southeast", "se" );
      }
      elsif( $command eq "sw" or $command eq "southwest" )
      {
          Transition( "southwest", "sw" );
      }
      elsif( $command eq "in" )
      {
          Transition( "in", "in" );
      }
      elsif( $command eq "out" or $command eq "exit" )
      {
          Transition( "out", "out" );
      }
      elsif( $command eq "write" )
      {
        if( $scope )
        {
          WriteFile( $scope );
        }
        else
        {
          print "Syntax: write <filename>\n";
        }
      }
      elsif( $command eq "addlocation" )
      {
          my $location_name = "";
          my $location_specifier = "";
          my $location_description = "";

          print "Short name for location?";
          $location_name = <STDIN>;
          chomp $location_name;
          print "Specifier:You are ... $location_name.";
          $location_specifier = <STDIN>;
          chomp $location_specifier;
          print "Enter a description...";
          $location_description = <STDIN>;
          chomp $location_description;

          $locations{$location_name} = $location_description;
          $locspecifiers{$location_name} = $location_specifier;
          print "#    Added $location_name\n";
      }
      elsif( $command eq "addexit" ) # god command
      {
          my $exit_label = "";
          my $exit_dirn = "";
          my $exit_locn = "";
          my $exit_text = "";
          my $exit_oneway = "";

          print "Which direction? (e.g.n,s,w,e,nw,ne,sw,se,u,d,in,out; (or roomname.n for locs other than here but complementary exit won't work)";
          $exit_dirn = <STDIN>;
          chomp $exit_dirn;
          while( $exit_locn eq "" )
          {
            print "Which location does it lead to? (Press enter to see a list)";
            $exit_locn = <STDIN>;
            chomp $exit_locn;
            if( $exit_locn eq "" )
            {
              print "TODO!\n";
            }
          }
          print "What should I say when user takes this exit? (Enter nothing for default)";
          $exit_text = <STDIN>;
          chomp $exit_text;
          print "Enter n if this is a one way exit (Enter nothing to create a complementary return exit)";
          $exit_oneway = <STDIN>;
          chomp $exit_oneway;

          if( index ($exit_dirn, '.') < 0 )
          {
            $exit_label = $current_loc . '.' . $exit_dirn;
          }
          else
          {
            $exit_label = $exit_dirn;
          }
          $exits{$exit_label} = $exit_locn;
          $exitingtext{$exit_label} = $exit_text;
          if( $exit_oneway eq "" )
          {
            if( $exit_dirn eq "n" ) {$exit_dirn = "s";}
            elsif( $exit_dirn eq "s" ) {$exit_dirn = "n";}
            elsif( $exit_dirn eq "e" ) {$exit_dirn = "w";}
            elsif( $exit_dirn eq "w" ) {$exit_dirn = "e";}
            elsif( $exit_dirn eq "nw" ) {$exit_dirn = "se";}
            elsif( $exit_dirn eq "ne" ) {$exit_dirn = "sw";}
            elsif( $exit_dirn eq "se" ) {$exit_dirn = "nw";}
            elsif( $exit_dirn eq "sw" ) {$exit_dirn = "ne";}
            elsif( $exit_dirn eq "in" ) {$exit_dirn = "out";}
            elsif( $exit_dirn eq "out" ) {$exit_dirn = "in";}
            elsif( $exit_dirn eq "u" ) {$exit_dirn = "d";}
            elsif( $exit_dirn eq "d" ) {$exit_dirn = "u";}
            $exit_label = $exit_locn. "." . $exit_dirn;
            $exits{$exit_label} = $current_loc;
            $exitingtext{$exit_label} = "";
          }
          print "#    Added $exit_label\n";
      }
      elsif( $command eq "rmexit" ) # god command
      {
              my $exit_label = $scope;
              if( index ($exit_label, '.') < 0 )
              {
                $exit_label = $current_loc . '.' . $exit_label;
              }
              delete $exits{$exit_label};
              if( $debug>=1 ) {print "#    Removed $exit_label\n";}

      }
      elsif( $command eq "addobject" )        # addobject spade:a:A dirty old spade:visible:It is too heavy
      {
          my @objParams = split( /:/, $scope  );
          if( @objParams >= 3 )
          {
              my $obj_label = $objParams[0];
              $objspecifiers{$obj_label} = $objParams[1];
              $objects{$obj_label} = $objParams[2];
              $obj_locations{$obj_label} = $current_loc;
              if( @objParams >= 4 )
              {
                $objvisibility{$obj_label} = $objParams[3];
              }
              else
              {
                $objvisibility{$obj_label} = 'visible';
              }
              if( @objParams >= 5 )
              {
                $objgetability{$obj_label} = $objParams[4];
              }
              else
              {
                $objgetability{$obj_label} = '';          # "" means getable
              }

              push @{ $locationobjects{$current_loc} }, $obj_label;
              if( $debug>=1 ) {print "#     Added $obj_label\n";}
          }
      }
      elsif( $command eq "addsynonym" )        # addsynonym building:house
      {
          my @objParams = split( /:/, $scope  );
          if( @objParams == 2 )
          {
            $objsynonyms{$objParams[0]} = $objParams[1];
          }
      }
      elsif( $command eq "chk" )
      {
          my $r = Chk( $scope );
          print "$r\n";
      }
      elsif( $command eq "take" or $command eq "get" )
      {
          if( exists $objsynonyms{$scope} )
          {
            $scope = $objsynonyms{$scope};
          }
          my $getable = "";
          if( exists $objgetability{$scope} )
          {
            $getable = $objgetability{$scope};
          }
          my $replenish = 0;
          if($getable eq "replenishes")
          {
              $replenish = 1;
              $getable = "";
          }
          if( $getable eq "" )
          {
              if( exists $obj_locations{$scope} and $obj_locations{$scope} eq $current_loc )
              {
                  TranslateObject( $scope, $current_loc, "local", $replenish );
                  print "You take the $scope.\n";

              }
              else
              {
                  print "It isn't here.\n";
              }
          }
          else
          {
              print "$getable\n";
          }

      }
      elsif( $command eq "drop" )
      {
          if( $obj_locations{$scope} eq "local" )
          {
              TranslateObject( $scope, "local", $current_loc );
              print "You drop the $scope.\n";
          }
          else
          {
              print "No object available\n";
          }
      }
      elsif( $command eq "inventory" or $command eq "inv" or $command eq "invent" ) #inventory
      {
          ShowObjects("local", 1);
      }
      elsif( $command eq "examine" or $command eq "exam" )
      {
          if( exists $objsynonyms{$scope} )
          {
            $scope = $objsynonyms{$scope};
          }
          if( (exists $obj_locations{$scope}) and ($obj_locations{$scope} eq $current_loc or $obj_locations{$scope} eq "local") )
          {
              print "$objects{$scope}.\n";
          }
          else
          {
              print "It is not here.\n";
          }
      }
      elsif( $command eq "summon" ) ## Administrator god command, automatically gets an object from anywhere to current loc
      {
          TranslateObject( $scope, "nowhere", $current_loc, 0 );
      }
      elsif( $command eq "own" ) ## Administrator god command, automatically gets an object from anywhere
      {
          TranslateObject( $scope, "nowhere", "local", 0 );
      }
      elsif( $command eq "hide" ) ## Administrator god command, automatically make a carried object disappear
      {
          TranslateObject( $scope, "local", "nowhere", 0 );
      }
      elsif( $command eq "state" ) ## Administrator god command, sets a state variable
      {
          if( $scope =~ m/(.*)=(.*)/ )
          {
            $states{$1} = $2;
          }
          else
          {
            if( exists $states{$scope} )
            {
              print "$states{$scope}\n";
            }
            else
            {
              print "null\n";
            }
          }
      }
      elsif( $command eq "debug" ) ## Administrator command, sets amount of debug output
      {
          $debug = $scope;
      }
      else
      {
        print "You can't do that.\n";
      }
    }
}

# Open test file
my $filename = $ARGV[0];

LoadFile( $filename );

print "\n\n\n\n----------------------------------------------------------------------------\n\n\n\nType INSTRUCTIONS for more info.\n";
while(1)
{
    if( Visited( $current_loc ) == 0 )
    {
        ShowRoom();
    }
    else
    {
        LineDump( $current_loc );
    }
    ShowExits();
    ShowObjects( $current_loc, 0 );
    push @visited_locations, $current_loc;
    if( @visited_locations > 5 )
    {
        shift @visited_locations;
    }
    print "\n>";
    my $command = <STDIN>;
    chomp $command;
    ExecuteCommand($command);
    print "\n";

}


# "get spade" didn't work but "take spade" did.
# Have alias for objects, e.g. rusty nail == nail, stone whale == whale so that "get nail" works.

# maze 1 to fountain: neene
# maze 1 to shed: seesswww
# fountain to maze 1:wswws
# shed to maze 1:eeennwwn
