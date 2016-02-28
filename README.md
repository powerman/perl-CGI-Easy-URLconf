[![Build Status](https://travis-ci.org/powerman/perl-CGI-Easy-URLconf.svg?branch=master)](https://travis-ci.org/powerman/perl-CGI-Easy-URLconf)
[![Coverage Status](https://coveralls.io/repos/powerman/perl-CGI-Easy-URLconf/badge.svg?branch=master)](https://coveralls.io/r/powerman/perl-CGI-Easy-URLconf?branch=master)

# NAME

CGI::Easy::URLconf - map url path to handler sub and vice versa

# VERSION

This document describes CGI::Easy::URLconf version v2.0.0

# SYNOPSIS

    use CGI::Easy::URLconf qw( setup_path path2view set_param );

    setup_path(
        '/about/'               => \&myabout,
        '/terms.php'            => \&terms,
        qr{\A /articles/ \z}xms => \&list_all_articles,
    );
    setup_path(
        qr{\A /articles/(\d+)/ \z}xms
            => set_param('year')
            => \&list_articles,
        qr{\A /articles/tag/(\w+)/(\d+)/ \z}xms
            => set_param('tag','year')
            => \&list_articles,
    );
    setup_path( POST =>
        '/articles/'            => \&add_article,
    );

    my $r = CGI::Easy::Request->new();
    my $handler = path2view($r);


    use CGI::Easy::URLconf qw( setup_view view2path with_params );

    setup_view(
        \&list_all_articles     => '/articles/',
        \&list_articles         => [
            with_params('tag','year')   => '/articles/tag/?/?/',
            with_params('year')         => '/articles/?/',
        ],
    );

    # set $url to '/about/'
    my $url = view2path( \&myabout );

    # set $url to '/articles/'
    my $url = view2path( \&list_all_articles );

    # set $url to '/articles/2010/?month=12'
    my $url = view2path( \&list_articles, year=>2010, month=>12 );

# DESCRIPTION

This module provide support for clean, user-friendly URLs. This can be
archived by configuring web server to run your CGI/FastCGI script for any
url requested by user, and let you manually dispatch different urls to
corresponding handlers (subroutines). Additionally, you can take some
CGI parameters from url's path instead of usual GET parameters.

    The idea is to set rules when CGI/FastCGI starts using:
      a) setup_path() - to map url's path to handler subroutine
         (also called "view")
      b) setup_view() - to map handler subroutine to url
    and then use:
      a) path2view() - to get handler subroutine matching current url's path
      b) view2path() - to get url matching some handler subroutine
         (for inserting into HTML templates or sending redirects).

Example:

    # -- while CGI/FastCGI initialization
    setup_path(
        '/articles/'        => \&list_articles,
        '/articles.php'     => \&list_articles,
        '/index.php'        => \&show_home_page,
    );
    setup_path( POST =>
        '/articles/'        => \&add_new_article,
    );

    # -- when beginning to handle new CGI/FastCGI request
    my $r = CGI::Easy::Request->new();
    my $handler = path2view($r);
    # $handler now set to:
    #   \&list_articles   if url path /articles/ and request method is GET
    #   \&add_new_article if url path /articles/ and request method is POST
    #   \&list_articles   if url path /articles.php (any request method)
    #   \&show_home_page  if url path /index.php (any request method)
    #   undef             (in all other cases)

    # -- while CGI/FastCGI initialization
    setup_view(
        \&list_articles     => '/articles/',
        # we don't have to configure mapping for \&show_home_page
        # and \&add_new_article because their mappings can be
        # unambiguously automatically detected from above setup_path()
    );

    # -- when preparing reply (HTML escaping omitted for simplicity)
    printf '<a href="%s">Articles</a>', view2path(\&list_articles);
    printf '<form method=POST action="%s">', view2path(\&add_new_article);
    # -- or redirecting to another url
    my $h = CGI::Easy::Headers->new();
    $h->redirect(view2path(\&show_home_page));

These two parts (setup\_path() with path2view() and setup\_view() with view2path())
can be used independently - for example, you don't have to use
setup\_view() and view2path() if you prefer to hardcode urls in HTML templates
instead of generating them dynamically. But using both parts will let you
configure _all_ urls used in your application in single place, which make
it easier to control and modify them.

In addition to simple constant path to handler and vice versa mapping you
can also map any path matching regular expression and even copy some data
from path to GET parameters. Example:

    # make /article/123/ same as /index.php?id=123
    # use same handler for any url beginning with /old/
    setup_path(
        '/article.php'          => \&show_article,
        qr{^/article/(\d+)/$}   => set_param('id') => \&show_article,
        qr{^/old/}              => \&unsupported,
    );

    # generate urls like /article/123/ dynamically
    setup_view(
        \&show_article          => [
            with_params('id')       => '/article/?/',
        ],
    );
    $url = view2path(\&show_article, id=>123);

# INTERFACE 

## setup\_path

    setup_path(
        '/path'             =>              $HANDLER,
        qr{^/path/(\d+)/$}  => @CALLBACKS,  $HANDLER,
        ...
    );
    setup_path( $METHOD =>
        '/path'             =>              $HANDLER,
        qr{^/path/(\d+)/$}  => @CALLBACKS,  $HANDLER,
        ...
    );

Configure mapping of url's path to handler subroutine (which will be used
by path2view()).
Can be called multiple times and will just **add** new mapping rules on each call.

If optional METHOD parameter defined, then all mapping rules in this
setup\_path() call will be applied only for requests with that HTTP method.
If METHOD doesn't used, then these rules will be applied to all HTTP methods.
If some path match both rules defined for current HTTP method and rules
defined for any HTTP methods, will be used rule defined for current HTTP
method.

MATCH parameter should be either SCALAR (string equal to url path) or
Regexp (which can match any part of url path).

HANDLER is REF to your subroutine, which will be returned by path2view()
when this rule will match current url.

Between MATCH and HANDLER any amount of optional CALLBACK subroutines can
be used. These CALLBACKS will be called when MATCH rule matches current
url with two parameters: CGI::Easy::Request object and ARRAYREF with
contents of all capturing parentheses (when MATCH rule is Regexp with
capturing parentheses). Usual task for such CALLBACKS is convert "hidden"
CGI parameters included in url path into usual `$r->{GET}` parameters.

Return nothing.

## path2view

    $handler = path2view( $r );

Take CGI::Easy::Request object as parameter, and analyse this request
according to rules defined previously using setup\_path().

Return: HANDLER if find rule which match current request, else undef().

## set\_param

    $callback = set_param( @names );

Take names of `{GET}` parameters which should be set using parts of
url path selected by capturing parentheses in MATCH Regexp.

Return CALLBACK subroutine suitable for using in setup\_path().

## setup\_view

    setup_view(
        \&HANDLER1 => $PATH,
        \&HANDLER2 => \@PATH,
        ...
    );

Configure mapping of handler subroutine to url path (which will be used by
view2path()).
Can be called multiple times and will just **add** new mapping rules on each call.

HANDLER must be REF to user's subroutine used to handle requests on PATH.

PATH can be either STRING or ARRAYREF.

If PATH is ARRAYREF, then this array should consist of CALLBACK =>
TEMPLATE pairs. CALLBACK is subroutine which will be executed by
view2path() with single parameter `\%params`, and should return
either FALSE if this CALLBACK unable to handle these %params, or ARRAYREF
with values to substitute into path TEMPLATE. TEMPLATE is path STRING
which may contain '?' symbols - these will be replaced by values returned
in ARRAYREF by CALLBACK which successfully handle %params.

Example: map \\&handler to /first/ or /second/ with 50% probability

    setup_view(
        \&handler   => [
            sub { return rand < 0.5 ? [] : undef }  => '/first/',
            sub { return []                      }  => '/second/',
        ],
    );

Example: map \\&handler to random article with id 0-999

    setup_view(
        \&handler   => [
            sub { return [ int rand 1000 ] }    => '/article/?/',
        ],
    );

Return nothing.

## view2path

    $url = view2path( \&HANDLER, %params );

Take user handler subroutine and it parameters, and convert it to url
according to rules defined previously using setup\_view().

Example:

    setup_view(
        \&handler   => 'index.php',
    );
    my $url = view2path(\&handler, a=>'some string', b=>[6,7]);
    # $url will be: 'index.php?a=some%20string&b=6&b=7'

If simple mapping from STRING to HANDLER was defined using setup\_path(),
and this is only mapping to HANDLER defined, then it's not necessary to
define reverse mapping using setup\_view() - it will be defined
automatically.

Example:

    setup_path(
        '/articles/'    => \&list_articles,
    );
    my $url = view2path(\&list_articles);
    # $url will be: '/articles/'

Return: url. Throw exception if unable to make url.

## with\_params

    $callback = with_params( @names );

Take names of parameters which **must** exists in %params given to
view2path().

Return CALLBACK subroutine suitable for using in setup\_view().

# SUPPORT

## Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at [https://github.com/powerman/perl-CGI-Easy-URLconf/issues](https://github.com/powerman/perl-CGI-Easy-URLconf/issues).
You will be notified automatically of any progress on your issue.

## Source Code

This is open source software. The code repository is available for
public review and contribution under the terms of the license.
Feel free to fork the repository and submit pull requests.

[https://github.com/powerman/perl-CGI-Easy-URLconf](https://github.com/powerman/perl-CGI-Easy-URLconf)

    git clone https://github.com/powerman/perl-CGI-Easy-URLconf.git

## Resources

- MetaCPAN Search

    [https://metacpan.org/search?q=CGI-Easy-URLconf](https://metacpan.org/search?q=CGI-Easy-URLconf)

- CPAN Ratings

    [http://cpanratings.perl.org/dist/CGI-Easy-URLconf](http://cpanratings.perl.org/dist/CGI-Easy-URLconf)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/CGI-Easy-URLconf](http://annocpan.org/dist/CGI-Easy-URLconf)

- CPAN Testers Matrix

    [http://matrix.cpantesters.org/?dist=CGI-Easy-URLconf](http://matrix.cpantesters.org/?dist=CGI-Easy-URLconf)

- CPANTS: A CPAN Testing Service (Kwalitee)

    [http://cpants.cpanauthors.org/dist/CGI-Easy-URLconf](http://cpants.cpanauthors.org/dist/CGI-Easy-URLconf)

# AUTHOR

Alex Efros &lt;powerman@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2009- by Alex Efros &lt;powerman@cpan.org>.

This is free software, licensed under:

    The MIT (X11) License
