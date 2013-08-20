package App::CurseX::Editor;

use Moo::Role;
use Curses;
use Curses::UI::Common;
use Class::Monkey qw<Curses::UI::TextEditor>;
canpatch 'Curses::UI::Common';

override CUI_TAB => sub { "  " }, qw<Curses::UI::Common>;
override draw_text => sub {
    my $this = shift;

    my $no_doupdate = shift || 0;
    return $this if $Curses::UI::screen_too_small;
 
    # Return immediately if this object is hidden.
    return $this if $this->hidden;
 
    # Turn on underlines and fill the screen with lines
    # if neccessary.
    if ($this->{-showlines} or $this->{-reverse}) {
        $this->{-canvasscr}->attron(A_UNDERLINE)
        	if ($this->{-showlines});

        $this->{-canvasscr}->attron(A_REVERSE)
        	if ($this->{-reverse});

        for my $y (0..$this->canvasheight-1) {
            $this->{-canvasscr}->addstr($y, 0, " "x($this->canvaswidth));
        }
    }
 
    # Draw the text.
    for my $id (0 .. $this->canvasheight - 1) {

    	# Let there be color
    	if ($Curses::UI::color_support) {
    		my $co = $Curses::UI::color_object;
    		my $pair = $co->get_color_pair(
                 $this->{-fg},
                 $this->{-bg});
 
    		$this->{-canvasscr}->attron(COLOR_PAIR($pair));
 
        }
 
        if (defined $this->{-search_highlight} 
            and $this->{-search_highlight} == ($id+$this->{-yscrpos})) {
            $this->{-canvasscr}->attron(A_REVERSE) if (not $this->{-reverse});
            $this->{-canvasscr}->attroff(A_REVERSE) if ($this->{-reverse});
        }
        else {
            $this->{-canvasscr}->attroff(A_REVERSE) if (not $this->{-reverse});
            $this->{-canvasscr}->attron(A_REVERSE) if ($this->{-reverse});
        }
 
        my $l = $this->{-scr_lines}->[$id + $this->{-yscrpos}];
        if (defined $l) {
            # Get the part of the line that is in view.
            my $inscreen = '';
            my $fromxscr = '';
            if ($this->{-xscrpos} < length($l)) {
                $fromxscr = substr($l, $this->{-xscrpos}, length($l));
                $inscreen = (
                	$this->text_wrap(
            			$fromxscr, 
            			$this->canvaswidth, 
            			NO_WORDWRAP
            		)
            	)->[0];
            }

 			# Reverse any subroutines to find them easily
 			if ($inscreen =~ /^\s*?sub\s*/) {
 				$this->{-canvasscr}->attron(A_REVERSE);
 			}

            # Masquerading of password fields.
            if ($this->{-singleline} and defined $this->{-password}) {
                # Don't masq the endspace which we
                # added ourselves.
                $inscreen =~ s/\s$//; 
     
                # Substitute characters.
                $inscreen =~ s/[^\n]/$this->{-password}/g;
            }
 
            # Clear line.
            $this->{-canvasscr}->addstr(
                $id,
                0, 
        		" " x $this->canvaswidth
        	);
 
            # Strip newline and replace by diamond character
            # if the showhardreturns option is on.
            if ($inscreen =~ /\n/) {
                $inscreen =~ s/\n//;
                $this->{-canvasscr}->addstr($id, 0, $inscreen);
                if ($this->{-showhardreturns}) {
                    if ($this->root->compat) {
                    	$this->{-canvasscr}->addch($id, scrlength($inscreen),'@');
                    }
                    else {
                    	$this->{-canvasscr}->attron(A_ALTCHARSET);
                    	$this->{-canvasscr}->addch($id, scrlength($inscreen),'`');
                    	$this->{-canvasscr}->attroff(A_ALTCHARSET);
                    }
                }
            }
            else {
                $this->{-canvasscr}->addstr($id, 0, $inscreen);
            }
             
            # Draw overflow characters.
            if (not $this->{-wrapping} and $this->{-showoverflow}) {
                $this->{-canvasscr}->addch($id, $this->canvaswidth-1, '$')
                    if $this->canvaswidth < scrlength($fromxscr);

                $this->{-canvasscr}->addch($id, 0, '$')
                    if $this->{-xscrpos} > 0;
            }
 
        }
        else {
            last;
        }
    }
 
    # Move the cursor.
    # Take care of TAB's    
    if ($this->{-readonly}) {
        $this->{-canvasscr}->move(
            $this->canvasheight-1,
            $this->canvaswidth-1
        );
    }
    else {
        my $l = $this->{-scr_lines}->[$this->{-ypos}];
        my $precursor = substr(
            $l, 
            $this->{-xscrpos},
            $this->{-xpos} - $this->{-xscrpos}
        );
 
        my $realxpos = scrlength($precursor);
        $this->{-canvasscr}->move(
            $this->{-ypos} - $this->{-yscrpos}, 
            $realxpos
        );
    }
     
    $this->{-canvasscr}->attroff(A_UNDERLINE) if $this->{-showlines};
    $this->{-canvasscr}->attroff(A_REVERSE) if $this->{-reverse};
    $this->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
    return $this;
}, qw<Curses::UI::TextEditor>;

sub cursor_pagedown()
{
    
}

1;