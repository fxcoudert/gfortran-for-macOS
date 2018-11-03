#!/usr/bin/perl -w
#
# mkdmg.pl
# Version 1.0
# $Revision: 1.17 $
# $Date: 2004/02/05 02:14:39 $
#
# Copyright 2002 Evan Jones <ejones@uwaterloo.ca>
# http://www.eng.uwaterloo.ca/~ejones/
#
# Released under the BSD Licence, but I would appreciate it if you email
# me if you find this script useful, or if you find any bugs I should fix.
#
# Permission to use, copy, modify, distribute, and sell this software and its
# documentation for any purpose is hereby granted without fee, provided that
# the above copyright notice appear in all copies and that both that
# copyright notice and this permission notice appear in supporting
# documentation.  No representations are made about the suitability of this
# software for any purpose.  It is provided "as is" without express or 
# implied warranty.
#
# Inspired by createDiskImage:
# http://graphics.stepwise.com/Articles/Technical/ProjectBuilder-DMG-Scripts.dmg
#
# Contributions:
# Ben Hines <bhines@alumni.ucsd.edu> - File names with periods and spaces
#
# TODO: Handle spaces in script mode.

use strict;

# Parse command line options
use Getopt::Std;

# TOOL CONFIGURATION
# Customize the tools that are used as you wish
# Note: These are all arrays to avoid undesired shell expansion

# Program that performs copies. You may prefer CpMac.
# If you want to use UFS, you need to run "cp" as root (I suggest using sudo)
my @copy = qw{cp};
my @copyOptions = qw{-R};

# Command to use to expand shell metacharacters: A string because we WANT to use the shell
my $expand = "/bin/ls -d";
sub shellExpandFileName( $ )
{
	# expands the parameter using ls and the shell
	my $arg = shift();
	return split( ' ', `$expand $arg 2> /dev/null` );
}

# Create disk images
my @createImage = qw{hdiutil create};
my @createImageOptions = qw{-megabytes 200 -type SPARSE -fs HFS+ -quiet -volname};

# Mounting disk images
my $mountImage = "hdid";

# Unmounting disk images
my @unmountImage = qw{hdiutil eject};
my @unmountImageOptions = qw{-quiet};

# Converting disk images
my @convertImage = qw{hdiutil convert};
#my @convertImageOptions = qw{-format UDZO -imagekey zlib-level=9 -quiet -o};
my @convertImageOptions = qw{-format UDRO -quiet -o};

# Compressing disk images
my %compressCommands = (
	'.dmg.bz2' => [ qw{nice bzip2 --best --force} ],
	'.dmg.gz' => [ qw{nice gzip --best --force} ],
	'.dmg' => undef,
);
my $compressCommand = undef;
my $compressedImage = undef;

# BEGIN PROGRAM

my %commandLineSwitches;
my $getoptsSucceeded = getopts( 'sv', \%commandLineSwitches );

my $verbose = exists( $commandLineSwitches{v} );
my $scriptMode = exists( $commandLineSwitches{s} );

# Validate command line options
if ( ! $getoptsSucceeded || ( $scriptMode && @ARGV < 1 ) || ( ! $scriptMode && @ARGV < 2 ) )
{
    print <<EOF;
usage: mkdmg.pl [OPTION]... <ImageName> [FILE]...
	-v	Verbose: Prints messages about each step
	-s	Script mode: Reads source/destination from standard input
EOF
    exit( 0 );
}

# Grab the size and image name arguments.
my $readonlyImage = shift();
my $specifiedImage = $readonlyImage;

# Match a compression format based on extension
$compressedImage = undef;
while ( my ($extension, $command) = each %compressCommands )
{
	my $re = $extension;
	$re =~ s/\./\\./;
	if ( $readonlyImage =~ /^(.*)$re$/ )
	{
		$readonlyImage = $1;
		$compressCommand = $compressCommands{$extension};
		$compressedImage = "$readonlyImage$extension";
	}
}

if ( ! defined $compressedImage )
{
	# We must have a "compressed image" name, or else no extension (default compressed image)
	fail( "Unable to determine output file type based on the extension: $2" ) if ( $readonlyImage =~ /^(.*)(\.[^.]*)$/ );

	$compressCommand = $compressCommands{".dmg.bz2"};
	$compressedImage = "$readonlyImage.dmg.bz2";
}

fail( "Zero length file name: Please specify a name without extension" ) if ( length $readonlyImage == 0 );

$readonlyImage .= ".dmg"; # Make sure it ends in .dmg

# Other file names and paths: based on the read-only image name
my $sparseImage = "$readonlyImage.sparseimage";
my $volumeName = $readonlyImage;
$volumeName =~ s/\.dmg$//;
my $mountPath = "/Volumes/$volumeName";

# Don't overwrite temporary files or mount when a volume with the same name is mounted
my @createdFiles = ( $sparseImage, $readonlyImage );
push( @createdFiles, $compressedImage ) if ( defined $compressCommand );
foreach my $file ( @createdFiles, $mountPath )
{
    # If the file is specified on the command line, it is okay to clobber it
    if ( $file ne $specifiedImage && -e $file )
    {
        print( "error: $file already exists\n" );
        exit( 1 );
    }
}
# Since we haven't created any files yet, don't put any on the list
@createdFiles = ();

# Find all the files we are going to copy
my @source;
my @destination;
if ( $scriptMode )
{
	# Split input on white space
	my @values = ();
	while ( <> )
	{
		push( @values, split( ' ', $_ ) );
	}
		
	my $input = 1;
	foreach my $value ( @values )
	{
		if ( $input )
		{
			push( @source, $value );
			$input = 0;
		}
		else
		{
			push( @destination, $value );
			$input = 1;
		}
	}
	
	# There is an error if the number of source files does not match the number of destination files
	fail( "Uneven number of input lines: A source file does not have a destination" ) if ( @source != @destination );
}
else
{
	# For command line mode we do no renaming or shell expansion: Just do it as is
	foreach my $line ( @ARGV )
	{
		push( @source, $line );
		push( @destination, "" );
	}
}

# Verify that we have input
fail( "No input files specified" ) if ( ! @source );

# Verify that we can find all the source files
foreach my $sourceFile ( @source )
{
	my @expandedSource = ( $sourceFile );	
	# If we are in script mode, expand shell characters
	if ( $scriptMode )
	{
		@expandedSource = shellExpandFileName( $sourceFile );
		fail( "Files not found: $sourceFile" ) if ( @expandedSource == 0 );
	}
	
	foreach my $file ( @expandedSource )
	{
		fail( "Cannot not find: $file (matched $sourceFile)" ) if ( ! -e $file );
		fail( "Cannot read: $file (matched $sourceFile)" ) if ( ! -r $file );
	}
	print "$sourceFile matches " . join( ", ", @expandedSource ) . "\n" if ( $verbose );
}

# Create the image and format it
print( "Creating temporary disk image: $sparseImage...\n" ) if ( $verbose );
push( @createdFiles, $sparseImage );
my $code = system( @createImage, $readonlyImage, @createImageOptions, $volumeName );
fail( "Creating temporary disk image failed" ) if ( $code || ! -e $sparseImage );

# Mount the disk image
print( "Mounting temporary disk image: $sparseImage...\n" ) if ( $verbose );
my $output = `$mountImage '$sparseImage'`;
fail( "Disk image not mounted at $mountPath" ) if ( ! -e $mountPath );

fail( "Could not determine mount device" ) if ( $output !~ m{^(/dev/disk\d+)\s+\S+\s*$}m );
my $mountDevice = $1;

# Copy files to the disk image
print( "Copying files...\n" ) if ( $verbose );

$code = 0;
for ( my $i = 0; $i < @source && ! $code; ++ $i )
{
	my @expandedSource = ( $source[$i] );	
	# If we are in script mode, expand shell characters
	@expandedSource = shellExpandFileName( $source[$i] ) if ( $scriptMode );

	my $destDir = ".";
	# If the source expands to multiple items, and a destination is specified,
	# the destination is a directory to be created.
	if ( @expandedSource > 1 && length $destination[$i] )
	{
		$destDir = $destination[$i];
	}
	# If the source is a single file and the destination contains slashes, make sure that each
	# directory before the file name is created.
	elsif ( $destination[$i] =~ m{(.*)/[^/]*$} )
	{
		$destDir = $1;
	}
		
	if ( ! -e "$mountPath/$destDir" )
	{
		print( "Creating destination directory: $mountPath/$destDir\n" ) if ( $verbose );
		
		# Split the directory into seperate parts ( dir1/dir2/dir3 => dir1, dir2, dir3 )
		my @hierarchy = split( /\//, $destDir );
		$destDir = "";
		foreach my $subdirectory ( @hierarchy )
		{
			$destDir .= "/$subdirectory";
			mkdir( "$mountPath$destDir" ) or fail( "Could not create directory: $mountPath$destDir: $!" ) if ( ! -e "$mountPath$destDir" );
		}		
	}

	$code = system( @copy, @copyOptions, @expandedSource, "$mountPath/$destination[$i]" );
	fail( "Files did not copy successfully" ) if ( $code );
}

# Unmount the disk image
print( "Unmounting temporary disk image: $sparseImage...\n" ) if ( $verbose );
$code = system( @unmountImage, $mountDevice, @unmountImageOptions );
fail( "Unmounting disk image failed" ) if ( $code  or -e $mountPath );

# Create the read-only image
# Formats (from largest to smallest):
# UDRO - Read only uncompressed
# UDCO - ADC compressed
# UDZO - Zlib compress (specify -imagekey zlib-level=9)
# UDRO.gz - Read only gzip compressed
# UDRO.bz2 - Read only bzip2 compressed (BEST)
print( "Creating read only disk image: $readonlyImage\n" ) if ( $verbose );
push( @createdFiles, $readonlyImage );
system( @convertImage, $sparseImage, @convertImageOptions, $readonlyImage );
unlink( $sparseImage );
unlink( "._$sparseImage" ) if ( -e "._$sparseImage" ); # Remove "resource fork" on any non HFS file systems
fail( "Read only image: $readonlyImage does not exist" ) if ( ! -e $readonlyImage );
unlink( "._$readonlyImage" ) or die "Could not unlink: $!" if ( -e "._$readonlyImage" ); # Remove "resource fork" on any non HFS file systems

print( "Read only disk image sucessfully created: $readonlyImage\n" ) if ( $verbose );

# Compress the disk image
if ( defined $compressCommand )
{
	print( "Compressing disk image: $readonlyImage to $compressedImage\n" ) if ( $verbose );
	push( @createdFiles, $compressedImage );
	$code = system( @$compressCommand, $readonlyImage );
	fail( "Compressing image failed" ) if ( $code or ! -e $compressedImage );
	
	print( "Compressed image sucessfully created: $compressedImage\n" ) if ( $verbose );
}

# Cleans up and quits in a gross fashion
sub fail
{
    my $string = shift();
    print( "error: $string\n" );
    
    # Gross hack: We exploit global variables to try and clean up gracefully
    system( @unmountImage, $mountDevice, @unmountImageOptions ) if ( defined $mountDevice );
    foreach my $file ( @createdFiles )
    {
        unlink $file if ( -e $file );
	unlink( "._$file" ) if ( -e "._$file" ); # Remove "resource fork" on any non HFS file systems
    }
    
    exit( 1 );
}
