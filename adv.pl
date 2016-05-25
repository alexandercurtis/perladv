#!/usr/bin/perl -w
# Copyright (c) 2006 Alex Curtis

use strict;
our %lines;
our %objects;
our %states;
our $current_line = "";
our %objlines;
our %lineobjs;
our @visited_rooms = ();
our %objspecifiers;
our %locspecifiers;
our %objgetability;
our %objvisibility;

## Translate an object line from line_a to line_b
sub TranslateObject
{
    my $object = shift;
    my $line_a = shift;
    my $line_b = shift;

    #print "Translate $object from $line_a to $line_b\n";

    $objlines{$object} = $line_b;

    #remove @{ $lineobjs{$current_line} }, $object;
    my $num = @{ $lineobjs{$line_a} };
    for( my $i = 0; $i < $num; $i++)
    {
        my $lineobj = @{ $lineobjs{$line_a} }[$i];
        #print "compare \"$lineobj\" and \"$object\" at $i\n";
        if( $lineobj eq $object )
        {
            splice @{ $lineobjs{$line_a} }, $i, 1;
            $i = $num;
            #print "match at $i\n";
        }
    }
    #print "compare $num\n";

    push @{ $lineobjs{$line_b} }, $object;
}

sub LineDump
{
    my $line = shift;
    print "You are $locspecifiers{$line} $line.\n";
}

sub ShowObjects
{
    my $line = shift;
    my $form = shift; # 0 = as if for room, 1 = as if for inventory.

    my $olist = "";
    my $count = 0;
    if( exists( $lineobjs{$line} ) )
    {
        my $num_objs = @{ $lineobjs{$line} };
        foreach my $o (@{ $lineobjs{$line} })
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
    foreach my $line( keys %lines )
    {
        print FH "l:$line:$lines{$line}\n";
    }
    foreach my $obj(keys %objects)
    {
        print FH "o:$obj:$objlines{$obj}:$objspecifiers{$obj}:$objgetability{$obj}:$objects{$obj}\n";
    }
    foreach my $state(keys %states)
    {
        print FH "x:$state:$states{$state}\n";
    }
    close( FH );
}


sub Transition
{
    my ( $dirn, $sdirn) = @_;
    if( defined $states{ $current_line . "." . $sdirn } )
    {
        $current_line = $states{ $current_line . "." . $sdirn };
        print "You travel " . $dirn . ".\n";
    }
    else
    {
        print "You cannot go $dirn.\n";
    }

    return $current_line;
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
    foreach my $state(keys %states)
    {
        if( $state =~ m/$current_line\.(.+)$/ )
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
    print "$lines{$current_line}\n";
}

sub Visited
{
    my $room = shift;
    foreach my $recently_visited (@visited_rooms)
    {
        if( $recently_visited eq $room )
        {
            return 1;
        }
    }
    return 0;
}
sub DumpFile
{
    print "LINES:\n";
    foreach my $line(keys %lines)
    {
        print "$line:$lines{$line}\n";
    }
    print "OBJECTS:\n";
    foreach my $obj(keys %objects)
    {
        print "$obj:$objlines{$obj}:$objects{$obj}\n";
    }
    print "STATES:\n";
    foreach my $state(keys %states)
    {
        print "$state:$states{$state}\n";
    }
    print "LINEOBJS:\n";
    for my $lo ( keys %lineobjs ) {
        print "$lo: @{ $lineobjs{$lo} }\n";
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
            if( defined $lines{$1} )
            {
                print "WARNING: line $1 already defined!\n";
            }
            $locspecifiers{$1} = $3;
            $lines{$1} = $5;
            if( $current_line eq "" )
            {
                $current_line = $1; # start at first room described in file
            }

        }
        elsif( m/^o:([^:]+):([^:]+):([^:]+):([^:]*):([^:]+):(.*)$/ )
        {
            if( defined $objects{$1} )
            {
                print "WARNING: object $1 already defined!\n";
            }
            $objects{$1} = $6;
            $objlines{$1} = $2;
            $objspecifiers{$1} = $3;
            $objgetability{$1} = $4;
            $objvisibility{$1} = $5;
            push @{ $lineobjs{$2} }, $1;
        }
        elsif( m/^x:((\w|\s)+.\w+):(.*)$/ )
        {
            if( defined $states{$1} )
            {
                print "WARNING: state for $1 already defined!\n";
            }
            $states{$1} = $3;
        }
        elsif( m/^#/ )
        {
            # a comment in the tst file.
        }
        else
        {
            print "WARNING: unparsed line: $_\n";
        }
    }
    close( FH );

    DumpFile();
}

##########################################################
##########################################################
##########################################################
##########################################################

if( scalar @ARGV != 1 )
{
    die("usage: tst.pl <test file>\n");
}

# Open test file
my $filename = $ARGV[0];

LoadFile( $filename );

while(1)
{
    LineDump( $current_line );
    if( Visited( $current_line ) == 0 )
    {
        ShowRoom();
    }
    ShowExits();
    ShowObjects( $current_line, 0 );
    push @visited_rooms, $current_line;
    if( @visited_rooms > 5 )
    {
        shift @visited_rooms;
    }
    print "\n>";
    my $scope = "";
    my $command = <STDIN>;
    chomp $command;
    my $sp_pos = index ($command, ' ');
    if( $sp_pos >= 0 )
    {
        $scope = substr ($command, $sp_pos+1);
        $command = substr ($command, 0, $sp_pos);
    }
    #print "command is \"$command\"\n";
    #print "scope is \"$scope\"\n";
    if( $command eq "quit" )
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
        DumpFile();
    }
    elsif( $command eq Chk("a") or $command eq Chk("abegu") )
    {
        Transition( Chk("abegu"), Chk("a") );
    }
    elsif( $command eq Chk("f") or $command eq Chk("fbhgu") )
    {
        Transition( Chk("fbhgu"), Chk("f") );
    }
    elsif( $command eq Chk("r") or $command eq Chk("rnfg") )
    {
        Transition( Chk("rnfg"), Chk("r") );
    }
    elsif( $command eq Chk("j") or $command eq Chk("jrfg") )
    {
        Transition( Chk("jrfg"), Chk("j") );
    }
    elsif( $command eq Chk("h") or $command eq Chk("hc") )
    {
        Transition( Chk("hc"), Chk("h") );
    }
    elsif( $command eq Chk("q") or $command eq Chk("qbja") )
    {
        Transition( Chk("qbja"), Chk("q") );
    }
    elsif( $command eq Chk("ar") or $command eq Chk("fbhgurnfg") )
    {
        Transition( Chk("fbhgurnfg"), Chk("ar") );
    }
    elsif( $command eq Chk("aj") or $command eq Chk("fbhgujrfg") )
    {
        Transition( Chk("fbhgujrfg"), Chk("aj") );
    }
    elsif( $command eq Chk("fr") or $command eq Chk("fbhgurnfg") )
    {
        Transition( Chk("fbhgurnfg"), Chk("fr") );
    }
    elsif( $command eq Chk("fj") or $command eq Chk("fbhgujrfg") )
    {
        Transition( Chk("fbhgujrfg"), Chk("fj") );
    }
    elsif( $command eq Chk("va") )
    {
        Transition( Chk("va"), Chk("va") );
    }
    elsif( $command eq Chk("bhg") or $command eq Chk("rkvg") )
    {
        Transition( Chk("bhg"), Chk("bhg") );
    }
    elsif( $command eq "write" )
    {
        WriteFile( $scope );
    }
    elsif( $command eq "al" )
    {
        my $sp_pos = index ($scope, ':');
        if( $sp_pos >= 0 )
        {
            my $line_label = substr ($scope, 0, $sp_pos);
            $lines{$line_label} = substr ($scope, $sp_pos+1);
            print "Added $line_label\n";
        }
    }
    elsif( $command eq "as" )
    {
        my $sp_pos = index ($scope, ':');
        if( $sp_pos >= 0 )
        {
            my $state_label = substr ($scope, 0, $sp_pos);
            $state_label = $current_line . '.' . $state_label;
            $states{$state_label} = substr ($scope, $sp_pos+1);
            print "Added $state_label\n";
        }
    }
    elsif( $command eq "ao" )
    {
        my $sp_pos = index ($scope, ':');
        if( $sp_pos >= 0 )
        {
            my $obj_label = substr ($scope, 0, $sp_pos);
            $objects{$obj_label} = substr ($scope, $sp_pos+1);
            $objlines{$obj_label} = $current_line;
            push @{ $lineobjs{$current_line} }, $obj_label;
            print "Added $obj_label\n";
        }
    }
    elsif( $command eq "chk" )
    {
        my $r = Chk( $scope );
        print "$r\n";
    }
    elsif( $command eq Chk("gnxr") or $command eq Chk("trg") )
    {
        my $getable = $objgetability{$scope};
        my $replenish = 0;
        if($getable eq "replenishes")
        {
            $replenish = 1;
            $getable = "";
        }
        if( $getable eq "" )
        {
            if( $objlines{$scope} eq $current_line )
            {
                TranslateObject( $scope, $current_line, "local", $replenish );
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
    elsif( $command eq Chk("qebc") )
    {
        if( $objlines{$scope} eq "local" )
        {
            TranslateObject( $scope, "local", $current_line );
            print "You drop the $scope.\n";
        }
        else
        {
            print "No object available\n";
        }
    }
    elsif( $command eq Chk("vairagbel") or $command eq Chk("vai") ) #inventory
    {
        ShowObjects("local", 1);
    }
    elsif( $command eq "examine" or $command eq "exam" )
    {
        if( (exists $objlines{$scope}) and ($objlines{$scope} eq $current_line or $objlines{$scope} eq "local") )
        {
            print "$objects{$scope}.\n";
        }
        else
        {
            print "It is not here.\n";
        }
    }

    print "\n";

}


