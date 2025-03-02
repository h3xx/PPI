#!/usr/bin/perl

# Exhaustively test all possible Perl programs to a particular length

use lib 't/lib';
use PPI::Test::pragmas;
use Test::More; # Plan comes later

use Params::Util qw( _INSTANCE );
use PPI ();
use PPI::Test qw( quotable );
use Helper 'safe_new';

# When distributing, keep this in to verify the test script
# is working correctly, but limit to 2 (maaaaybe 3) so we
# don't slow the install process down too much.
my ( $MAX_CHARS, $ITERATIONS, $LENGTH )  = ( 2, 1000, 190 );
my @ALL_CHARS = (
	qw{a b c f g m q r s t w x y z V W X 0 1 8 9},
	';', '[', ']', '{', '}', '(', ')', '=', '?', '|', '+', '<',
	'>', '.', '!', '~', '^', '*', '$', '@', '&', ':', '%', ',',
	'\\', '/', '_', ' ', "\n", "\t", '-',
	"'", '"', '`', '#', # Comment out to make parsing more intense
);

# Cases known to have failed in the past.
my @FAILURES = (
	# Failed cases 3 chars or less
	'!%:', '!%:',  '!%:',  '!%:',  '!*:', '!@:',  '%:',  '%:,',
	'%:;', '*:',   '*:,',  '*::',  '*:;', '+%:',  '+*:', '+@:',
	'-%:', '-*:',  '-@:',  ';%:',  ';*:', ';@:',  '@:',  '@:,',
	'@::', '@:;',  '\%:',  '\&:',  '\*:', '\@:',  '~%:', '~*:',
	'~@:', '(<',   '(<',   '=<',   'm(',  'm(',   'm<',  'm[',
	'm{',  'q(',   'q<',   'q[',   'q{',  's(',   's<',  's[',
	's{',  'y(',   'y<',   'y[',   'y{',  '$\'0', '009', '0bB',
	'0xX', '009;', '0bB;', '0xX;', "<<'", '<<"',  '<<`', '&::',
	'<<a', '<<V',  '<<s',  '<<y',  '<<_',

	# Failed cases 4 chars long.
	# This isn't the complete set, as they tend to fail in groups
	# of 50 or so, but I've used a representative sample.
	'm;;_', 'm[]_', 'm]]_', 'm{}_', 'm}}_', 'm--_', 's[]a', 's[]b',
	's[]0', 's[];', 's[]]', 's[]=', 's[].', 's[]_', 's{}]', 's{}?',
	's<>s', 's<>-',
	'*::0', '*::1', '*:::', '*::\'', '$::0',  '$:::', '$::\'',
	'@::0', '@::1', '@:::', '&::0',  '&::\'', '%:::', '%::\'',

	# More-specific single cases thrown up during the heavy testing
	'$:::z', '*:::z', "\\\@::'9:!", "} mz}~<<ts", "<\@<<q-r8\n/",
	"W<<s`[\n(", "X<<f+X;g(<~\" \n1\n*", "c<<t* 9\ns\n~^{s ",
	"<<V=-<<Wt", "[<<g/.<<r>\nV",
	"( {8",
);

plan tests => (9722 + ($ENV{AUTHOR_TESTING} ? 1 : 0));




#####################################################################
# Code/Dump Testing

my $last_index = scalar(@ALL_CHARS) - 1;
LENGTHLOOP:
foreach my $len ( 1 .. $MAX_CHARS ) {
	# Initialise the char array
	my @chars    = (0) x $len;

	# The main test loop
	my $failures = 0;  # simulate subtests
	CHARLOOP:
	while ( 1 ) {
		# Test the current set of chars
		my $code = join '', map { $ALL_CHARS[$_] } @chars;
		unless ( length($code) == $len ) {
			die "Failed sanity check. Error in the code generation mechanism";
		}
		$failures += 1 if !compare_code( $code );

		# Increment the last character
		$chars[$len - 1]++;

		# Cascade the wrapping as needed
		foreach ( reverse( 0 .. $len - 1 ) ) {
			next CHARLOOP unless $chars[$_] > $last_index;
			if ( $_ == 0 ) {
				# End of the iterations, move to the next length
				last CHARLOOP;
			}

			# Carry to the previous char
			$chars[$_] = 0;
			$chars[$_ - 1]++;
		}
	}
	is( $failures, 0, "No tokenizer failures for all $len-length programs" );
}





#####################################################################
# Test a series of random strings

for ( 1 .. $ITERATIONS ) {
	# Generate a random string
	my $code = join( '',
		map { $ALL_CHARS[$_] }
		map { int(rand($last_index) + 1) }
		(1 .. $LENGTH)
		);
	ok( compare_code($code), "round trip successful" );
}




#####################################################################
# Test all the failures

foreach my $code ( @FAILURES ) {
	ok( compare_code($code), "round trip of old failure successful" );
}


exit(0);





#####################################################################
# Support Functions

sub compare_code {
	my ( $code ) = @_;

	my $round_tripped = round_trip_code($code);
	my $code_quoted   = quotable($code);
	diag        #
	  "input:\n---\n$code_quoted\n---\n",
	  'output: "' . quotable($round_tripped) . '"',
	  'shorted failing substring: "' . quotable( quickcheck($code) ) . '"'
	  unless    #
	  my $ok = ( $code eq $round_tripped );

	if ( scalar(keys %PPI::Element::PARENT) != 0 ) {
		$ok = 0;
		my $code_quoted = quotable($code);
		diag( qq{ Stale \%PARENT entries at the end of testing of "$code_quoted"} );
	}
	%PPI::Element::PARENT = %PPI::Element::PARENT;

	return $ok;
}


sub round_trip_code {
	my ( $code ) = @_;

	my $result;

	my $Document  = eval {
		# use Carp 'croak'; $SIG{__WARN__} = sub { croak('Triggered a warning') };
		safe_new \$code;
	};
	if ( _INSTANCE($Document, 'PPI::Document') ) {
		$result = $Document->serialize;
	}

	return $result;
}


# Find the shortest failing substring of known bad string
sub quickcheck {
	my $code       = shift;
	my $fails      = $code;
	# use Carp 'croak'; $SIG{__WARN__} = sub { croak('Triggered a warning') };

	while ( length $fails ) {
		chop $code;
		safe_new \$code or last;
		$fails = $code;
	}

	while ( length $fails ) {
		substr( $code, 0, 1, '' );
		safe_new \$code or return $fails;
		$fails = $code;
	}

	return $fails;
}
