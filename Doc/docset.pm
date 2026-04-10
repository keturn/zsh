use strict;
use warnings;

package Texinfo::Config;

use Text::ParseWords 'parse_line';

# HIGHLIGHT_SYNTAX=pygments isn't working for unknown reasons, so supply full pygmentize command line.
# `nowrap` because texi2any already has them in a `pre` element.
texinfo_set_from_init_file('HIGHLIGHT_SYNTAX', 'pygmentize -l %l -f html -O nowrap=true');
texinfo_set_from_init_file('HIGHLIGHT_SYNTAX_DEFAULT_LANGUAGE', 'zsh');

texinfo_set_from_init_file('EXTRA_HEAD', <<'EOD'
<link rel="icon" type="image/svg+xml" sizes="any" href="icon.svg">
<link rel="icon" type="image/png" sizes="16x16" href="icon.png">
<link rel="icon" type="image/png" sizes="32x32" href="icon@2.png">
EOD
);

# texi2any's default is to split every node to its own file.
# zsh-doc's choice of splitting on chapter makes larger pages where more context is visible
# by scrolling without having to navigate to a different node.
# It does mean the big chapters (i.e. Modules) get very, very big.
texinfo_set_from_init_file('SPLIT', 'chapter');

# For hosted pages, NODE_FILES adds redirect pages to make nodes easier to link to.
# For docset use, these files can be used to discover nodes to generate index entries for.
# (An alternative might be to parse the output of `--internal-links`.)
# https://www.gnu.org/software/texinfo/manual/texinfo/html_node/Invoking-texi2any.html#index-_002d_002dnode_002dfiles
texinfo_set_from_init_file('NODE_FILES', "True");

# browsers like having the language set for accessibility and hyphenation.
texinfo_set_from_init_file('documentlanguage', 'en');

if (!defined $ENV{VERSION_DATE} or !defined $ENV{VERSION}) {
  die 'Expected VERSION and VERSION_DATE environment variables. Try sourcing Config/version.mk.';
}
my $version_date = $ENV{VERSION_DATE};
# It's quoted? I guess that's the reason for the Makefile's d=`echo $d`.
$version_date = join(" ", parse_line('\s+', 0, $version_date)) if $version_date =~ /^'/;
texinfo_set_from_init_file('PRE_BODY_CLOSE',
  "<footer>Zsh version $ENV{VERSION}, released on $version_date.</footer>");


=pod
grouped_navigation_panel formats the panel as:
 <nav-panel>
   <nav-group>
     <nav-button>next
     <nav-button>previous
     <nav-buton>up
   <nav-group>
     <nav-button>contents
     <nav-button>index

The implementation closely follows the _default_format_navigation_panel and it might not be worth
thinking about perl this much for such a minor formatting change but here we are.
=cut

sub grouped_navigation_panel {
  my ($self, $buttons, $cmdname, $source_command, $vertical, $in_header) = @_;
  return '' if ref($buttons) ne 'ARRAY';
  my $format_button = $self->formatting_function('format_button');
  my $items_ref = [];
  my @groups = ( $items_ref );
  foreach my $button (@$buttons) {
    my $direction;
    if (ref($button) eq 'ARRAY'
        && defined $button->[0] && ref($button->[0]) eq '') {
      $direction = $button->[0];
    } elsif (defined $button && ref($button) eq '') {
      $direction = $button;
    }
    my ($active, $passive, $need_delimiter) =
      &$format_button($self, $button, $source_command);
    next unless defined $active;
    if ($direction eq 'Space' and @$items_ref) {
      $items_ref = [];
      push @groups, $items_ref;
      next;
    }
    my @classes = ('nav-button');
    if ($need_delimiter) {
      push @classes, 'nav-delimited';
    }
    push @$items_ref, $self->html_attribute_class('span', [@classes]) . qq{>$active</span>};
  }
  my $result = '';
  for my $groupref ( @groups ) {
    $result .= $self->html_attribute_class('div', ['nav-group']) . '>' . join("", @$groupref) . '</div>';
  }
  return '' unless $result;
  return $self->html_attribute_class('div', ['nav-panel']) . qq{>$result</div>\n};
};
texinfo_register_formatting_function('format_navigation_panel', \&grouped_navigation_panel);
