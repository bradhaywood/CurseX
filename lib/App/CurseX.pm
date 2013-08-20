package App::CurseX;

use Moo;
use Curses;
use Curses::UI;
use Term::ANSIColor;
use Sysadm::Install qw(tap slurp);

our $VERSION = '0.001';

has cui     => ( is => 'ro', default => sub { Curses::UI->new( -color_support => 1 ) });
has editors => ( is => 'rw', default => sub { [] } );
has number  => ( is => 'rw', default => sub { 0 } );
has win     => ( is => 'rw' );
has viewer  => ( is => 'rw' );
has text    => ( is => 'rw' );
has runner  => ( is => 'rw' );
has focused => ( is => 'rw' );
has command => ( is => 'rw' );
has bold    => ( is => 'ro', default => sub { color("bold") } );
has reset   => ( is => 'ro', default => sub { color("reset") } );

sub add_new_editor {
    my ($self) = @_;

    my $ed = $self->text(
        $self->win->add(
            "editor_" . $self->number, 'TextEditor',
            -title      => "Untitled (" . $self->number . ")",
        	-padtop     => 0,
            -padbottom     => 1,
        	-border     => 1,
            -vscrollbar => 'right',
            -wrapping   => 1,
            #-bfg        => 'blue'
            -bfg             => "green",
            -bbg             => "black",
            -sfg             => "white",
            -sbg             => "black",
            -bg              => "black",
            -fg              => "white",
            -bold            => 1,
        )
    );
   
    $ed->{-canvasscr}->attron(A_BOLD); 
    $self->focused($self->number);
    
    push @{$self->editors}, $ed;
    $self->number($self->number+1);
    
    $ed->clear_binding('loose-focus');
    return $ed;
}

sub saveFile {
    my ($self, $file) = @_;
    my $editor = $self->editors->[$self->focused];
    my $currentfile;
    if (open my $fh, ">", $file) {
        print $fh $editor->text;
        if (close $fh) {
            $self->cui->dialog(-message => "File \"$file\"\nsuccessfully saved");
            $currentfile = $file;
        }
        else {
            $self->cui->error(-message => "Error on closing file \"$file\":\n$!");
        }
    }
    else {
        $self->cui->error(-message => "Can't write to $file:\n$!");
    }
}

sub init {
	my ($self) = @_;

	$self->win(
		$self->cui->add(
    		'status', 'Window',
            -bg => 'black',
            -fg => 'white',
            -bold => 1,
    	)
   	);

    $self->runner(
        $self->win->add(
            'runner', 'TextViewer',
            -title      => 'Output',
            -padbottom  => 1,
            -vscrollbar => 'right',
            -border     => 1,
            -wrapping   => 1,
        )
    );

    $self->runner->{-canvasscr}->attron(A_BOLD);

    $self->add_new_editor();

    $self->command(
	    $self->win->add(
		    'command', 'TextEntry',
		    -x => 0,
		    -y => -1,
		    -padtop => 5,
            -bg => "blue",
            -fg => "white",
	    )
    );

    $self->command->{-canvasscr}->attron(A_BOLD);
    my $new = sub {
        my $ed = $self->add_new_editor();
        $ed->focus();
    };

	my $quit = sub {
		my $return = $self->cui->dialog(
        	-message   => "Do you really want to quit?",
        	-title     => "Are you sure?", 
        	-buttons   => ['yes', 'no'],
		);
		
		exit 0 if $return;
	};

    my $changeFocus = sub {
        my $next = $self->focused + 1;
        if ($self->editors->[$next]) {
            $self->editors->[$next]->focus();
            $self->focused($next);
        }
        else {
            $self->editors->[0]->focus();
            $self->focused(0);
        }
    };

    my $openFile = sub {
        my $file = $self->cui->loadfilebrowser(
            -title => "Open file",
            -mask  => [
                ['.', 'All files (*)'      ],
                ['\.txt$', 'Text files (*.txt)' ],
                ['\.pm$',  'Perl modules (*.pm)'],
            ],
        );

        if ($file) {
            my $str = slurp($file);
            $self->editors->[$self->focused]->title($file);
            $self->editors->[$self->focused]->text($str);
        }
    };

    my $runCode = sub {
        my $editor = $self->editors->[$self->focused];
        open my $fh, '>', 'intperl.tmp' or do {
            $self->cui->dialog("Couldn't open intperl.tmp for reading!");
            return 0;
        };

        print $fh $editor->get();
        close $fh;

        my ($stdout, $stderr, $exit) = tap $^X, "intperl.tmp";
        if ($stderr) {
            $self->runner->text("Error: $stderr");
        }
        else {
            $self->runner->text($stdout);
        }
        
        #$editor->text('');
        unlink 'intperl.tmp';
    };

    my $saveFile = sub {
        my $editor = $self->editors->[$self->focused];
        my $currentfile = $editor->title;
        my $file = $self->cui->savefilebrowser(
	        -file         => $editor->title,
        );
        return unless defined $file;

        $self->saveFile($file);
    };

    my $tabbed = sub {
        my $editor = $self->editors->[$self->focused];
        my $pos = $editor->{-xpos};
        my $row = $editor->{-ypos};
        $editor->{-xpos} = $pos+4;
        $editor->{-ypos} = $row;
        $editor->{-canvasscr}->addstr($row, $pos, " ");
        $editor->{-canvasscr}->noutrefresh;
    };

    my $enterCommand = sub {
        my $editor = $self->editors->[$self->focused];
        my $string = $self->command->get();
        $self->command->text('');
        $editor->focus();
        my ($cmd, @args) = split ' ', $string;
        if (substr($cmd, 0, 1) eq '>') {
            $cmd = shift @args;
            if ($cmd eq 'exit' or $cmd eq 'quit') { $quit->(); }
            if ($cmd eq 'open') {
                my $file;
                if (@args) {
                    $file = $args[0];
                    if (-f $file) {
                        open my $fh, "<", $file or do {
                            $self->cui->error(-message => $!);
                            return;
                        };
                        close $fh;
                        my $data = slurp $file;
                        $editor->text($data);
                        $editor->title($file);
                    }
                    else {
                        $self->cui->error(-message => "File does not exist");
                        return;
                    }
                }
                else {
                    $openFile->();
                }
            }
            if ($cmd eq 'close') {
                splice @{$self->editors}, $self->focused, 1;
                $self->win->delete("editor_" . $self->focused);
                if ($self->editors->[$self->focused+1]) {
                    $self->focused($self->focused+1);
                }
                else {
                    $self->focused(0);
                }

                $self->editors->[$self->focused]->focus();
            }
            if ($cmd eq 'w') {
                $self->saveFile($self->editors->[$self->focused]->title);
            }
        }
    };

    $self->editors->[0]->clear_binding('loose-focus');
	$self->command->set_binding( $enterCommand, "343" );
	$self->cui->set_binding( $quit, "\cQ" );
    $self->cui->set_binding( $new, "\cN" );
    $self->cui->set_binding( $changeFocus, "\cW" );
    $self->cui->set_binding( $openFile, "\cO" );
    $self->cui->set_binding( $saveFile, "\cS" );
    $self->cui->set_binding( $runCode, "\cR" );
    $self->cui->set_binding( sub {
        $self->command->focus();
        $self->command->text('> ');
        $self->command->pos(3)
    }, "\cC" );

    #$self->cui->set_binding( $tabbed, "\t" );

    if (@ARGV) {
        my $file = $ARGV[0];
        if (-f $file) {
            my $str = slurp $file;
            my $bold = A_BOLD;
            $str =~ s/sub/${bold}sub/g;
            $self->editors->[$self->focused]->title($file);
            $self->editors->[$self->focused]->text($str);
        }
    }

    $self->editors->[0]->focus();
	$self->cui->mainloop();
}

=head1 NAME

App::CurseX - Curses-based Text Editor

=head1 DESCRIPTION

Ever wanted to use a text editor that wasn't as good as vim, lacked most of its features, had zero syntax highlighting, but was written in pure perl? 
App::CurseX is a curses-based (console) text editor written in nothing but Perl.

=head1 FEATURES

=over 4

=item * Installs binary for quick access (B<cursex>)

=item * Multiple editors in a single window

=item * Toggle a command line interface

=item * Dialogs for Opening and Saving files

=item * Instantly run your perl code inside the editor (be careful what you run)

=back

=head1 SHORTCUTS

=head2 Ctrl+N

Create a new editor and automatically set focus

=head2 Ctrl+W

Focuses on next available editor window

=head2 Ctrl+O

Displays open file dialog

=head2 Ctrl+S

Displays save dialog

=head2 Ctrl+C

Focuses command line input (See COMMANDS for more information)

=head2 Ctrl+X

Deletes an entire line

=head2 Ctrl+Q

Prompts to exit CurseX

=head1 COMMANDS

=head2 open [file]

Opens a file in the currently focused editor. If no argument is passed then the open dialog will show.

=head2 close

Closes the current editor and moves to the next available one

=head2 exit|quit

Prompts to quit CurseX

=head1 AUTHOR

Brad Haywood <brad@perlpowered.com>

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut

1;
__END__
