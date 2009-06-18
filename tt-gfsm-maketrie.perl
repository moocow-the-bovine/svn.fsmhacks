#!/usr/bin/perl -w

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);
use Gfsm;

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $progname     = basename($0);
our $verbose      = 2;

our $input_fsmfile = undef;
our $input_labfile = undef;

our $output_fsmfile = '-';
our $output_labfile = undef;

our $reverse_input= undef;
our $char_symbols = undef;
our $word_strings = undef;
our $list_all     = 0;     ##-- if true, *very* sparse literal list is built
our $bos_str      = '__$'; ##-- string to use as  a BOS marker
our $eos_str      = '__$'; ##-- string to use as an EOS marker
our $eow_str      = '__#'; ##-- string to use as an EOW marker

select(STDERR); $|=1; select(STDOUT);

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'man|m'  => \$man,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- Initialization / Input
	   'input-trie|it|t|input-fsm|ifsm|if|f=s' => \$input_fsmfile,
	   'input-labels|il|l|input-alphabet|ia|a=s' => \$input_labfile,

	   ##-- Output
	   'output-trie|ot|output-fsm|ofsm|of|F=s' => \$output_fsmfile,
	   'output-labels|ol|L|output-alphabet|oa|A=s' => \$output_labfile,

	   ##-- behavior
	   'bos|b:s' => \$bos_str,
	   'eos|e:s' => \$eos_str,
	   'eow|E:s' => \$eow_str,
	   'reverse|r|suffixes|s!' => \$reverse_input,
	   'word-symbols|wordsyms|words|w!' => sub { $char_symbols = !$_[1]; },
	   'char-symbols|charsyms|chars|c!' => sub { $char_symbols = $_[1]; },
	   'sent-strings|sentences|sents|S!' => sub { $word_strings = !$_[1]; },
	   'word-strings|W!' => sub { $word_strings = $_[1]; },
	   'list-all|list|all|la!'  => \$list_all,
	  );

pod2usage({
	   -exitval=>0,
	   -verbose=>0
	  }) if ($help);
pod2usage({
	   -exitval=>0,
	   -verbose=>1
	  }) if ($man);

if ($version || $verbose >= 1) {
  print STDERR "$progname version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## Subs: messages
##----------------------------------------------------------------------

## undef = vmsg($level,@msg)
##  + print @msg to STDERR if $verbose >= $level
sub vmsg {
  my $level = shift;
  print STDERR (@_) if ($verbose >= $level);
}

##----------------------------------------------------------------------
## Subs: generic: add a string

## undef = add_string(\@symbols, $count)
##  + implicity reverses @symbols in reverse-input mode
##  + implicitly appends $bos_lab,$eos_lab to (reversed) @symbols if defined
sub add_string {
  ($string_symbols,$string_count) = @_;
  @string_labs = (
		  map {
		    $lab = $abet->get_label($_);
		    warn("$progname: label overflow!") if ($lab==$Gfsm::noLabel); ##-- sanity check
		    $lab
		  } @$string_symbols
		 );
  @string_labs = reverse(@string_labs) if ($reverse_input);
  unshift(@string_labs, $bos_lab) if (defined($bos_lab));
  push(@string_labs, $eos_lab) if (defined($eos_lab));

  if (!$list_all) {
    ##-- trie mode
    $fsm->add_path(\@string_labs,[],$string_count);
  }
  else {
    ##-- list mode
    $qfrom = $qto = $fsm->root();
    foreach $lab (@string_labs) {
      $qto = $fsm->add_state();
      $fsm->add_arc($qfrom,$qto,$lab,$Gfsm::epsilon,$string_count);
      $qfrom = $qto;
    }
    $fsm->final_weight($qto,$string_count);
  }
}

##----------------------------------------------------------------------
## Subs: symbols=chars, strings=words

sub process_chars_words {
  #$sent = shift;
  foreach $tok (@$sent) {
    $txt = ref($tok) ? $tok->text : $tok;
    @tchars = split(//,$txt);
    add_string(\@tchars,1);
  }
}

##----------------------------------------------------------------------
## Subs: symbols=chars, strings=sents

sub process_chars_sents {
  #$sent=shift;
  #
  @schars = map {
    $txt = ref($_) ? $_->text : $_;
    ( split(//,$txt), (defined($eow_str) && $eow_str ne '' ? $eow_str : qw()) )
  } @$sent;

  add_string(\@schars,1);
}

##----------------------------------------------------------------------
## Subs: symbols=words, strings=words

sub process_words_words {
  #$sent=shift;
  @toksym=qw();
  foreach $tok (@$sent) {
    $txt = ref($tok) ? $tok->text : $tok;
    $toksym[0] = $txt;

    add_string(\@toksym,1);
  }
}


##----------------------------------------------------------------------
## Subs: symbols=words, strings=sents

sub process_words_sents {
  #$sent=shift;
  @wordsyms = map { ref($_) ? $_->text : $_ } @$sent;
  add_string(\@wordsyms,1);
}

##----------------------------------------------------------------------
## Subs: I/O: get_sentence()

## \@sent = tt_get_sentence($ttfh)
sub tt_get_sentence {
  my $ttfh = shift;
  my $s    = [];
  my ($w,$rest);
  while (<$ttfh>) {
    chomp;
    next if (/^\%\%/);
    if (/^\s*$/) {
      last if (@$s);
      next;
    }
    ($w,$rest) = split(/\t/,$_,2);
    push(@$s,$w);
  }
  return @$s ? $s : undef;
}


##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
push(@ARGV, '-') if (!@ARGV);

##-- report config
print STDERR
  ("$progname config:\n",
   "  + Files:\n",
   "    - input labels : ", ($input_labfile||'(none)'), "\n",
   "    - input FSM    : ", ($input_fsmfile||'(none)'), "\n",
   "    - output labels: ", ($output_labfile||'(none)'), "\n",
   "    - output FSM   : ", ($output_fsmfile||'(none)'), "\n",
   "  + Options:\n",
   "    - bos          : ", ($bos_str||'(none)'), "\n",
   "    - eos          : ", ($eos_str||'(none)'), "\n",
   ($char_symbols && !$word_strings
    ? ("    - eow          : ", ($eow_str||'(none)'), "\n")
    : qw()),
   "    - direction    : ", ($reverse_input ? 'right-to-left (STA)' : 'left-to-right (PTA)'), "\n",
   "    - symbols      : ", ($char_symbols  ? 'characters' : 'words'), "\n",
   "    - strings      : ", ($word_strings  ? 'words' : 'sentences'), "\n",
   "    - FSM          : ", ($list_all  ? 'list' : 'trie'), "\n",
  );

##-- initialize alphabet
our $abet = Gfsm::Alphabet->new();
if (defined($input_labfile)) {
  vmsg(1,"$progname: loading input labels '$input_labfile'...");
  $abet->load($input_labfile)
    or die("$progname: load failed for input labels file '$input_labfile': $!");
  vmsg(1,"loaded.\n");
}
##-- ensure epsilon
if (!defined($abet->find_key(0))) {
  $abet->get_label('<epsilon>', 0);
}
##-- ensure bos,eos, maybe eow
our $bos_lab = defined($bos_str) && $bos_str ne '' ? $abet->get_label($bos_str) : undef;
our $eos_lab = defined($eos_str) && $eos_str ne '' ? $abet->get_label($eos_str) : undef;
our $eow_lab = ($char_symbols && !$word_strings && defined($eow_str) && $eow_str ne ''
		? $abet->get_label($eow_str)
		: undef);

##-- initialize FSM
#our $fsm = Gfsm::Automaton->newTrie();
our $fsm = Gfsm::Automaton->new();
if (defined($input_fsmfile)) {
  vmsg(1,"$progname: loading input FSM '$input_fsmfile'...");
  $fsm->load($input_fsmfile)
    or die("$progname: load failed for input FSM file '$input_fsmfile': $!");
  vmsg(1,"$progname: loaded.\n");
} else {
  $fsm->semiring_type($Gfsm::SRTReal);
}

##-- ensure root state exists
$fsm->root($fsm->add_state()) if ($fsm->root == $Gfsm::noState);

##-- process corpora
select(STDERR); $|=1; select(STDOUT);
foreach $ttfile (@ARGV) {
  vmsg(2,"$progname: processing TT file: $ttfile ...");

  open(TT,"<$ttfile") or die("$progname: open failed for '$ttfile': $!");

  $i=-1;
  while ($sent=tt_get_sentence(\*TT)) {
    vmsg(2,'.') if (($i++ % 100) == 0);

    if ($char_symbols) {
      if ($word_strings) { process_chars_words(); }
      else               { process_chars_sents(); }
    }
    else { # if ($word_symbols)
      if ($word_strings) { process_words_words(); }
      else               { process_words_sents(); }
    }
  }

  vmsg(2," done.\n");
}

##-- save stuff
if (defined($output_labfile)) {
  $abet->save($output_labfile)
    or die("$progname: save failed for labels file '$output_labfile': $!");
}

if (defined($output_fsmfile)) {
  $fsm->save($output_fsmfile)
    or die("$progname: save failed for fsm file '$output_fsmfile': $!");
}

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-gfsm-maketrie.perl - convert a .tt file to to a prefix- or suffix-tree acceptor

=head1 SYNOPSIS

 corpus2pta.perl OPTIONS [CORPUS_FILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 I/O Options:
   -input-fsm     GFSMFILE , -if GFSMFILE  # initial FSM
   -input-labels   LABFILE , -il  LABFILE  # initial labels
   -output-fsm    GFSMFILE , -of GFSMFILE  # output FSM
   -output-labels  LABFILE , -ol  LABFILE  # output labels

 Generation Options:
   -bos STR      , -b STR  # BOS symbol, prefixed to every path (default=__$)
   -eos STR      , -e STR  # EOS symbol appended to every path  (default=__$)
   -eow STR      , -E STR  # EOW symbol for (-c -S) mode        (default=__#)
   -reverse      , -r      # build suffix trie                  (default=PTA)
   -word-symbols , -w      # fsm symbols are input words        (default)
   -char-symbols , -c      # fsm symbols are input characters
   -sent-strings , -S      # fsm paths are input sentences      (default)
   -word-strings , -W      # fsm paths are input words
   -list-all     , -la     # build parallel list, not a trie

=cut

###############################################################
## OPTIONS
###############################################################
=pod

=head1 OPTIONS

=cut

###############################################################
# General Options
###############################################################
=pod

=head2 General Options

=over 4

=item -help

Display a brief help message and exit.

=item -version

Display version information and exit.

=item -verbose LEVEL

Set verbosity level to LEVEL.  Default=1.

=back

=cut


###############################################################
# Other Options
###############################################################
=pod

=head2 Other Options

=over 4

=item -someoptions ARG

Example option.

=back

=cut


###############################################################
# Bugs and Limitations
###############################################################
=pod

=head1 BUGS AND LIMITATIONS

Probably many.

=cut


###############################################################
# Footer
###############################################################
=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@ling.uni-potsdam.deE<gt>

=head1 SEE ALSO

perl(1).

=cut

