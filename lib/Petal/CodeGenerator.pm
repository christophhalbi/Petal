=head1 NAME

Petal::CodeGenerator - Turns canonicalized XML files
into Perl code.

=head1 SYNOPSIS

  use Petal::CodeGenerator;
  $code_data_ref = Petal::CodeGenerator->process ($base_dir, $canonical_data);

=head1 DESCRIPTION

=cut
package Petal::CodeGenerator;
use strict;
use warnings;
use Carp;

use vars qw /$base_dir $tokens $variables @code $indent $token_name %token_hash $token/;


# $class->process ($data_ref, $base_dir);
# ---------------------------------------
#   This (too big) subroutine converts the canonicalized template
#   data into Perl code which is ready to be evaled and executed
sub process
{
    my $class = shift;
    my $data_ref = shift;
    
    local $base_dir = shift;
    local $tokens = $class->_tokenize ($data_ref);
    local $variables = {};
    local @code = ();
    local $indent = 0;
    local $token_name = undef;
    local %token_hash = ();
    local $token = undef;
    
    push @code, "    " x $indent . "\$VAR1 = sub {";
    $indent++;
    push @code, "    " x $indent . "my \$hash = shift;";
    push @code, "    " x $indent . "my \@res = ();";
    
    foreach $token (@{$tokens})
    {
        if ($token =~ /^<\?petal:.*?\?>$/)
        {
	    ($token_name) = $token =~ /<\?petal:\s*([a-z]+)/;
	    %token_hash   = $token =~ /(\S+)\=\"(.*?)\"/gos;
	    
          CASE:
            for ($token_name)
	    {
                /^include$/   and do { $class->_include; last CASE };
		/^var$/       and do { $class->_var;     last CASE };
		/^if$/        and do { $class->_if;      last CASE };
		/^condition$/ and do { $class->_if;      last CASE };
                /^else$/      and do { $class->_else;    last CASE };
		/^repeat$/    and do { $class->_for;     last CASE };
		/^loop$/      and do { $class->_for;     last CASE };
		/^foreach$/   and do { $class->_for;     last CASE };
		/^for$/       and do { $class->_for;     last CASE };
		
		/^end$/ and do
                {
                    $indent--;
                    push @code, ("    " x $indent . "}");
                    last CASE;
                };
	    }
	}
	else
	{
            my $string = $token;
            $string =~ s/\@/\\\@/gsm;
            $string =~ s/\$/\\\$/gsm;
            $string =~ s/\n/\\n/gsm;
            $string =~ s/\n//gsm;
            $string =~ s/\"/\\\"/gsm;
            push @code, ("    " x $indent . 'push @res, "' . $string . '";');
        }
    }
    
    push @code, "    " x $indent . "return join '', \@res;";
    $indent--;
    push @code, "    " x $indent . "};";
    
    return join "\n", @code;
}


# $class->_include;
# -----------------
#   process a <?petal:include file="/foo/blah.html"?> file
sub _include
{
    my $class = shift;
    
    my $file = $token_hash{name} || $token_hash{file} ||
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $file and $file) or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    if (defined $base_dir and $base_dir)
    {
	push @code, ("    " x $indent . 
		     "push \@res, Petal->new (base_dir => '$base_dir', file => '$file' )->process (\$hash);");
    }
    else
    {
	push @code, ("    " x $indent . "push \@res, Petal->new (file => '$file' )->process (\$hash);");
    }
}


# $class->_var;
# -------------
#   process a <?petal:var name="blah"?> statement
sub _var
{
    my $variable = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'name' attribute is not defined";

    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    push @code, ("    " x $indent . "push \@res, \$hash->{'$variable'};");
}


# $class->_if;
# ------------
#   process a <?petal:if name="blah"?> statement
sub _if
{
    my $variable = $token_hash{name} or
        confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
        confess "Cannot parse $token : 'name' attribute is not defined";
		    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    push @code, ("    " x $indent . "if (\$hash->{'$variable'}) {");
    $indent++;
}


# $class->_else;
# --------------
#   process a <?petal:else name="blah"?> statement
sub _else
{
    $indent--;
    push @code, ("    " x $indent . "}");
    push @code, ("    " x $indent . "else {");
    $indent++;
};


# $class->_for;
# -------------
#   process a <?petal:for name="some_list" as="element"?> statement
sub _for
{
    my $variable = $token_hash{name} or
    confess "Cannot parse $token : 'name' attribute is not defined";
    
    (defined $variable and $variable) or
    confess "Cannot parse $token : 'name' attribute is not defined";
    
    my $as = $token_hash{as} or
    confess "Cannot parse $token : 'as' attribute is not defined";
    
    (defined $as and $as) or
    confess "Cannot parse $token : 'as' attribute is not defined";
    
    # set the variable in the $variables hash
    my $tmp = $variable;
    $tmp =~ s/\..*//;
    $variables->{$tmp} = 1;
    
    push @code, ("    " x $indent . "my \@array = \@{\$hash->{'$variable'}};");
    push @code, ("    " x $indent . "for (my \$i=0; \$i < \@array; \$i++) {");
    $indent++;
    push @code, ("    " x $indent . "my \$hash = new Petal::Hash (\%{\$hash});");
    push @code, ("    " x $indent . "my \$count= \$i + 1;");
    push @code, ("    " x $indent . "\$hash->{__count__}    = \$count;");
    push @code, ("    " x $indent . "\$hash->{__is_first__} = (\$count == 1);");
    push @code, ("    " x $indent . "\$hash->{__is_last__}  = (\$count == \@array);");
    push @code, ("    " x $indent . "\$hash->{__is_inner__} = (not \$hash->{__is_first__} and not \$hash->{__is_last__});");
    push @code, ("    " x $indent . "\$hash->{__even__}     = (\$count % 2 == 0);");
    push @code, ("    " x $indent . "\$hash->{__odd__}      = not \$hash->{__even__};");
    push @code, ("    " x $indent . "\$hash->{'$as'} = \$array[\$i];");
}


# $class->_tokenize ($data_ref);
# -----------------------------
#   Returns the data to process as a list of tokens:
#   ( 'some text', '<% a_tag %>', 'some more text', '<% end-a_tag %>' etc.
sub _tokenize
{
    my $self = shift;
    my $data_ref = shift;
    my @tags  = $$data_ref =~ /(<\?petal:.*?\?>)/gs;
    my @split = split /<\?petal:.*?\?>/s, $$data_ref;
    
    my $tokens = [];
    while (@split)
    {
        push @{$tokens}, shift (@split);
        push @{$tokens}, shift (@tags) if (@tags);
    }
    
    return $tokens;
}


1;


__END__
