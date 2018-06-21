#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use DateTime;

use MyModel;
use Util qw(
    printslow
    print_state_new
    print_state_main
    print_message
    get_key
    get_input
);

my $states = {
    NEW => 0,
    GUEST => 1,
    LOGGING_IN => 2,
    LOGGED_IN => 3,
    LOGGED_OUT => 4,
    MAIN => 5,
    MESSAGE_LIST => 6,
    MESSAGE_DISPLAY => 7,
    WRITE_MESSAGE => 8,
    REGISTER => 9
};

my $connection = MyModel->connect('mongodb://127.0.0.1/bbs');
my $users = $connection->collection('user');
my $posts = $connection->collection('post');

my $session = {};
$session->{state} = $states->{NEW};

# Quick'n'Dirty DB poppulation
#my $u1 = $users->create({ name => 'jbob the elder', pw => 'doe' });
#my $p1 = $posts->create({ subject => 'The aweseome first post', date => DateTime->now, text => "hi there, this is the first post"  });
#$p1->user($u1);
#$p1->save;
#$u1->save;

while ($session->{state} != $states->{LOGGED_OUT}) {
    if ($session->{state} == $states->{NEW}) {
        print_state_new;
        my $input = get_key;
        if ($input =~ m/l/i) {
            $session->{state} = $states->{LOGGING_IN};
        } elsif ($input =~ m/g/i) {
            $session->{state} = $states->{MESSAGE_LIST};
            $session->{auth} = 0;
        } elsif ($input =~ m/r/i) {
            $session->{state} = $states->{REGISTER};
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        }
    } elsif ($session->{state} == $states->{MESSAGE_LIST}) {
        print_state_main($posts, $session->{auth});
        my $input = get_key;
        if ($input =~ m/#/i) {
            printslow "#: ";
            $input = get_input;
            $session->{post_nr} = $input;
            $session->{state} = $states->{MESSAGE_DISPLAY};
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        }
    } elsif ($session->{state} == $states->{MESSAGE_DISPLAY}) {
        print_message($posts, $session->{post_nr});
        my $input = get_key;
        if ($input =~ m/#/i) {
            printslow "#: ";
            my $xxx = get_input;
            $session->{post_nr} = $input;
        } elsif ($input =~ m/l/i) {
            $session->{state} = $states->{MESSAGE_LIST};
        } elsif ($input =~ m/q/i) {
            $session->{state} = $states->{LOGGED_OUT};
        }
    }
}
printslow("OK, bye for now\n")


# Mandel Cheat-Sheet:

# Fields
# User;                                                          
#   name => ( isa => Str );                                                   
#   pw => ( isa => Str );                                                     
#   has_many posts => 'MyModel::Post';                                              
# Post;                                                          
#   subject => ( isa => Str );                                                
#   date => ( isa => DateTimeUTC );                                           
#   belongs_to user => 'MyModel::User';                                           
#   text => ( isa => Str );                                                   
#   has_one parent => 'MyModel::Post';          

#my $u1 = $users->create({ name => 'John', pw => 'doe' });
#my $p1 = $posts->create({ subject => 'first post', date => DateTime->now, text => "hi there, this is the first post"  });
#$p1->user($u1);
#$p1->save;
#$u1->save;

# All posts
# $array_ref = $posts->all;

# All users;
# $array_ref = $users->all;

# Count:
# $nr = $posts->count;
# $nr = $users->count;


## Find all posts by user
#for my $p (@{ $u1->posts }) {
#  warn $p->subject;
#  warn $p->user->name;
#  warn $p->date;
#}
