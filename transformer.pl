#! /local/bin/perl -s

# Transformer.pl version 0.45, 24.03.99
# Copyright 1999 Ole Dahle
# Purpose: Rewrite SDL diagrams (in PR/CIF format) to make them more readable
# Usage: perl transfomer.pl [-warn] [-insert] infile [outfile]

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


#Preferences:
$infile = "phase3.sdl";      
$showWarnings = 0;
$insertComments = 0;
$removeInvisibleJoins = 1;

$flowsPerPage = 4;  # Number of flows allowed on a page
$flowSpacing = 380; # Number of pixels between each flow
$pageWidth = 1500;
$pageHeight = 2200;

#Look for command line options
if($warn != 0) {$showWarnings = 0;}
if($insert != 0) {$insertComments = 0;}

$firstfile = 1;
foreach (@ARGV)
{ if(!(/^-/) && !$firstfile) {$outfile = $_;}
  if(!(/^-/) && $firstfile) {$infile = $_; $firstfile = 0;}
}
if($outfile eq "") {$outfile = "fixed_$infile";}

if($insertComments)
  {$flowsPerPage = $flowsPerPage/2; $flowSpacing = $flowSpacing *2;}
 
print "$infile $outfile $showWarnings $insertComments space: $flowSpacing\n";   

#Global variables
@sdlfile;      #Array that contains the SDL file
$i = $j = 0;   #Counters
$x=  $y = 0;   #Position variables
$statePosX = 0; $statePosY = 0; # Position of state symbol



#Initialize: Open infile, read it into the sdlfile array.
print "Transformer starting\n";
open(INPUT,$infile) or die("Could not open input file $infile.\n");
print "opening $infile\n";
@sdlfile = <INPUT>;
close(INPUT);

#Perform transformations

if($insertComments)
{ &insertTextExtensions;
  &makeSignalTextExtension;
}

if($removeInvisibleJoins)
{ &removeInvisibleJoins;}
&expandConnections;
&stateOnNewPage;
&alignPages;
&resolvePageOverflow;
&alignNextstates;
&removeEmptyPages;

if($showWarnings)
{ &warnShortNames;
  &warnBranchOnDecision;
}




#Write transformed SDL to file

open(OUTPUT,">$outfile") or die("Could not open output file $outfile.\n");
print "Writing to $outfile.\n";
foreach $outline (@sdlfile)
{ print OUTPUT "$outline";
}
close(OUTPUT);

#End of program

#----------- Subroutines representing transformational rules below-----------#


sub expandConnections
{ local(@connections) = ();
  local(@joins) = ();
  local(%definition) = 0;
  local($numberOfConnections) = 0;
  local($invisibleJoins) = 0;
  local(%used) = ();
  local($currentState);



 
  #Scan trough sdlfile, find all connections;
  $i = 0;
  while($i< @sdlfile)
  { if($sdlfile[$i] =~ /^join (\w+)/i) #Count occurences of join
    { #Lowercase connection name, works with norwegian characters: 
      $temp = $1; $temp =~ tr/A-ZÆØÅ/a-zæøå/; 

      #Count auto-generated, graphical connections separately
      if($temp =~ /^grst\d+/)
      {$invisibleJoins++;}
      else
      {$used{$temp}++;}
 
    }
    $i++;
  }

  @temp = %used;
  $numberOf = @temp;
  $numberOf = $numberOf/2;
  print "There are $numberOf connections and $invisibleJoins invisible joins used in the file.\n";

  # Treat each connection separately
  foreach $con (reverse sort keys(%used))
  { print "Connection $con was used $used{$con} times. Do you want to:\n";
    print "Expand all occurences?      (1)\n";
    print "Expand selected occurences? (2)\n";
    print "Turn it into a procedure?   (3)\n";
    print "Do nothing?     (Any other key)\n";
    $answer = <>;
    #print "$answer \n";

    if($answer ==1 || $answer ==2 || $answer ==1)
    {
    #Rescan sdlfile, since joins-wihtin-joins may have been expanded, and
    # increased the number of joins.
    $i = 0;
    foreach $temp( keys (%used)) {$used{$temp} = 0;}
     while($i< @sdlfile)
     {if($sdlfile[$i] =~ /^join (\w+)/i) #Count occurences of join
      { #Lowercase connection name, works with norwegian characters: 
        $temp = $1; $temp =~ tr/A-ZÆØÅ/a-zæøå/; 

        #Skip auto-generated, graphical connections
        if(!($temp =~ /^grst\d+/))
        {$used{$temp}++;}
       }
       $i++;
     }
    }

    # --- Expand connection ---
    if($answer == 1 || $answer == 2)
    { #Finding the definition of the connection      
      $i = 0;
      until(($sdlfile[$i] =~ /^connection $con/i) || $i == @sdlfile)
	{$i++};
 
     if($i == @sdlfile)
      {print "Couldn't find the definition of $con!\n";}
      else
      {
      $def = $i+2;
      $i = 0;
      $expandedJoins = 0;

      #Enter do-it-all or selected-only mode
      if($answer == 1) {$doit = 1;}
      else {$doit = 0; }

      while($i < @sdlfile)
      {  # Keep track of wich state we're in
         if($sdlfile[$i] =~ /^state (.+)(;|\n)/i) {$currentState = $1;}

        if($answer == 2 &&$sdlfile[$i] =~ /^join $con/i)
         { #Ask if in selected-only mode
           print "Found an occurence of $con in state $currentState.\n";
           print "Expand it? (y/n) ";
           $expand = <>;
           if($expand =~ /^y/i) {$doit = 1}
         }  

         if($sdlfile[$i] =~ /^join $con/i && $doit)
	 { $sdlfile[$i-1] =~ /^\/\* CIF Join \((\d+),(\d+)\)/i;
           #print "$1 $2 $sdlfile[$i-1]";
           $x=$1; $y=$2;
           print "Replacing an occurence of join $con in state $currentState.\n";
           splice(@sdlfile,$i-1,2);

	   if($def > $i) {$def -= 2;}  
           #print "Definition at $def, pointer at $i\n";

           $k = $def; $i--;
           #Find the label, find the coordinates
           $tmp = $k;
           until($sdlfile[$tmp] =~ /\/\* CIF/i && $sdlfile[$tmp] !~ /(Line|comment)/i)
	   { # Lines and comments are not at the same coordinates as the flow
             $tmp++;
           }
           $sdlfile[$tmp] =~ /\((\d+),(\d+)\)/;
           #print "$1,$2 $sdlfile[$tmp]";
           # Calculating offset:
           $x = $1+50 - $x; $y = $2 - $y;
           #print "Offset: x: $x y: $y\n";

           if($sdlfile[$k] =~ /^\/\* CIF Line/i) {$k++;} # Skip first line

           until($sdlfile[$k] =~ /^\/\* CIF End Label/i)
	   { 
            # Treat comments to the connection label specially:
            if(($sdlfile[$k-1] =~ /^connection/i) && 
              ($sdlfile[$k] =~ /\/\* CIF Comment \((\d+),(\d+)/i))
	    { #print "Moving comment...\n";
	      $tempx = $1-$x; $tempy = $2-$y;

              # Create Textbox instead of comment
              splice(@sdlfile,$i,0,"/* CIF Text ($tempx,$tempy),(300,400) */\n"); 
              $i++; $k++;  if($def > $i) {$def++; $k++;}
              splice(@sdlfile,$i,0,"/* Comment moved by Transformer:\n"); 
              $i++;  if($def > $i) {$def++; $k++;}

              # Skip the line to the old comment
	      if($sdlfile[$k] =~ /\/\* CIF Line/i) {$k++;}
 
              # Remove "comment '" from first line
              splice(@sdlfile,$i,0,"$sdlfile[$k]");
              print "Should be old comment: $sdlfile[$i]";
              $sdlfile[$i] =~ s/comment '//i;
              $i++; $k++; if($def > $i) {$def++; $k++;}
             

              # Put the rest of the comment in the box
              until($sdlfile[$k] =~ /^(;|:)/) # ':' is wrong, but used sometimes?
              { splice(@sdlfile,$i,0,"$sdlfile[$k]");
              #$sdlfile[$i] =~ s/\n/\*\/\n/;
              $i++; $k++; if($def > $i) {$def++; $k++;}
              }

              # Insert text box end instead of ';'
              print "$sdlfile[$k]"; 
             $sdlfile[$i-1] =~ s/'/\*\//; print "$sdlfile[$i-1]";
              splice(@sdlfile,$i,0,"/* CIF End Text */\n");
              $i++; $k++; if($def > $i) {$def++; $k++;}  
               
            }
            else  
          {splice(@sdlfile,$i,0,$sdlfile[$k]);

            # In some CIF statements, only the first (x,y) pair must be changed,
            # since the second (x,y) defines the size of the symbol.
            if($sdlfile[$i] =~ /\/\* CIF (Label|Join|Comment|Text) /i)
            { $sdlfile[$i]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
              $sdlfile[$i]=~ s/(\d+)\)/$1-$y/e; # Substitute 'y)' with y minus offset
              $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/; # Put the parantheses back in
            }

            elsif($sdlfile[$i] =~ /\/\* CIF/) 
            { $sdlfile[$i]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
              $sdlfile[$i]=~ s/(\d+)\)/$1-$y/ge; # Substitute 'y)' with y minus offset
              $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/g; # Put the parantheses back in
            }
             #print "$sdlfile[$i]";
             $i++; $k++; if($def > $i) {$def++; $k++;} 
           } #End comment /normal line  
           } #End inserting 
           if($answer ==2) {$doit = 0;} #Don't expand next one without asking
           $expandedJoins++;
         } #End expanding occurence
	 $i++;
      }


      #Deleting Connection definition
      if($expandedJoins == $used{$con}) #Only delete if all occurences were expanded
      {
      print "Deleting  definition of $con\n";
      $prevline = "";
      $i = 0;
      until($sdlfile[$i] =~ /^connection $con/i)
      	{$i++};
      $i--; # Start with the CIF label-statement above the connection statement
      until($prevline =~ /^endconnection/i)  
       { $prevline = $sdlfile[$i]; #print "$prevline";
         splice(@sdlfile,$i,1);
       }
      } #End deleting definition

    } #End found definiton

    } #End expanding connection
 

  # --- Turn connection into procedure
  if($answer == 3)
    { #Finding the definition of the connection      
      $i = 0;
      until(($sdlfile[$i] =~ /^connection $con/i) || $i == @sdlfile)
	{$i++};
 
     if($i == @sdlfile)
      {print "Couldn't find the definition of $con!\n";}
      else
      {
      $def = $i+1;
 
     until(($sdlfile[$i] =~ /^endconnection $con/i) || $i == @sdlfile)
	{ if($sdlfile[$i] =~ /^nextstate (\w+)/i)
	    {$returns++; $returnState = $1;}
         $i++;
        }   
 
    #@temp = %returns; $temp = @temp;
    if($returns > 2)
      { print "Connection $con has returns to more than one state!\n"; }
    else
      { #Open a file to put the new procedure in
        print "Creating procedure $con in separate file...\n";
        $filename = "$con.sdl";
        $overwrite = "n";
        until(!(-e "$filename") || $overwrite =~ /^y/i)
        { print "$filename exists. OK to overwrite? (y/n)\n";
          $overwrite = <>;
          if($overwrite =~ /^n/i)
          { print "Please supply a different name: ";
            $filename=<>;
            chop($filename);
          }
        }

        #Print the procedure to the file
        open(PROCFILE, ">$filename") or die("Failed to open $filename.\n");               
        print PROCFILE "/* CIF ProcedureDiagram */\n";
        print PROCFILE "/* CIF Page 1 (1900,2300) */\n";
        print PROCFILE "/* CIF Frame (0,0),(1900,2300) */\n";
        print PROCFILE "/* CIF Specific SDT Version 1.0 */\n";
        print PROCFILE "/* CIF Specific SDT Page 1 Scale 100 Grid (250,150) AutoNumbered */\n";
        print PROCFILE "Procedure $con;\n";
        print PROCFILE "/* CIF DefaultSize (200,100) */\n";
        print PROCFILE "/* CIF CurrentPage 1 */\n";
        print PROCFILE "/* CIF ProcedureStart (300,100) */\n";
        print PROCFILE "start ;\n";

       # Extract coordinates from label  symbol, evaluate offset
       $j = $def;
       $sdlfile[$j-2] =~ /\/\* CIF Label \((\d+),(\d+)\)/i;
       #print "$sdlfile[$j-2]";
       $x = $1-350;
       $y = $2-100;
       #print "x: $x y: $y $sdlfile[$j-2]\n";
    
       # Print the connection to the file, alter all coordinates according to offset
       until($sdlfile[$j] =~ /^\/\* CIF End Label/i)
       { 
           # Treat comments to the connection label specially:
            if(($sdlfile[$j-1] =~ /^connection/i) && 
              ($sdlfile[$j] =~ /\/\* CIF Comment \((\d+),(\d+)/i))
	    { print "Moving comment...\n";
	      $tempx = $1-$x; $tempy = $2-$y;

              # Create Textbox instead of comment
              print PROCFILE "/* CIF Text ($tempx,$tempy),(300,400) */\n"; $j++;
              print PROCFILE "/* Comment moved by Transformer:\n"; 


              # Skip the line to the old comment
	      if($sdlfile[$j] =~ /\/\* CIF Line/i) {$j++;}
 
              # Remove "comment '" from first line
                print "Should be old comment: $sdlfile[$i]";
              $sdlfile[$j] =~ s/comment '//i;
               $sdlfile[$j] =~ s/'\n/\*\/\n/; # If it's also the last
               print PROCFILE "$sdlfile[$j]"; $j++;
             

              # Put the rest of the comment in the box
              until($sdlfile[$j] =~ /^(;|:)/) # ':' is wrong, but used sometimes?
              {  $sdlfile[$j] =~ s/'\n/\*\/\n/;
                  print PROCFILE "$sdlfile[$j]";
                $j++;
              }

              # Insert text box end instead of ';'
              print "$sdlfile[$j]"; 
              print PROCFILE "/* CIF End Text */\n";
              $j++;   
               
            }
        
         # In a CIF label or Join statement, only the first (x,y) pair must be changed,
         # since the second (x,y) defines the size of the symbol.
         if($sdlfile[$j] =~ /\/\* CIF (Label|Join|Comment|Text) /i)
         { $sdlfile[$j]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
           $sdlfile[$j]=~ s/(\d+)\)/$1-$y/e; # Substitute 'y)' with y minus offset
           $sdlfile[$j]=~ s/(\d+),(\d+)/\($1,$2\)/; # Put the parantheses back in
         }

         elsif($sdlfile[$j] =~ /\/\* CIF/) 
         { $sdlfile[$j]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
           $sdlfile[$j]=~ s/(\d+)\)/$1-$y/ge; # Substitute 'y)' with y minus offset
           $sdlfile[$j]=~ s/(\d+),(\d+)/\($1,$2\)/g; # Put the parantheses back in
         }

         #Turn the nextStates into returns
         if($sdlfile[$j] =~ /\/\* CIF NextState \((\d+),(\d+)/i)
	 { $x = $1+50; $y = $2;
           $sdlfile[$j] = "/* CIF Return($x,$y),(100,100) */\n";
           $sdlfile[$j+1] = "return;\n";
         } 
         print PROCFILE "$sdlfile[$j]";
         $j++;
       }

       #Print the last part of the procedure to the file.
       print PROCFILE "/* CIF End ProcedureDiagram */\n";
       print PROCFILE "endprocedure $con;\n";

       close(PROCFILE);

       #Insert reference to the procedure in the beginning of sdlfile
       $i=0;
       until($sdlfile[$i] =~ /^\/\* CIF CurrentPage/i) {$i++;}
       splice(@sdlfile,$i+1,0,"/* CIF Procedure (600,100) */\n");
       splice(@sdlfile,$i+2,0,"/* CIF TextPosition (625,125) */\n");
       splice(@sdlfile,$i+3,0,"procedure $con referenced;\n");

       #Search through sdlfile and replace all joins to the connection with procedure calls
       $i = 0;
       while($i<@sdlfile)
       {
       if($sdlfile[$i] =~ /^join $con/i)
	 { $sdlfile[$i-1] =~ /^\/\* CIF Join \((\d+),(\d+)\)/i;
           $x=$1-50; $y=$2;
           #print "Replacing an occurence of $sdlfile[$i]\n";
           $sdlfile[$i-1] = "/* CIF ProcedureCall ($x,$y) */\n";
           $sdlfile[$i] = "call $con;\n";
           $x = $x+100; $y = $y+100; $y2 = $y+50;
           splice(@sdlfile,$i+1,0,"/* CIF Line ($x,$y),($x,$y2) */\n");
           $x = $x-100;
           splice(@sdlfile,$i+2,0,"/* CIF NextState ($x,$y2) */\n");
           splice(@sdlfile,$i+3,0,"nextstate $returnState;\n");
         } #End replacing join
        $i++;
       } #End replacing all joins with calls
 
      #Deleting Connection definition
      print "Deleting  definition of $con\n";
      $prevline = "";
      $i = 0;
      until($sdlfile[$i] =~ /^connection $con/i)
      	{$i++};
      #$i = $def-2;
       $i--; # Start with the Label CIF statement above the connection statement 
      until($prevline =~ /^endconnection/i)  
       { $prevline = $sdlfile[$i]; #print "$prevline";
         splice(@sdlfile,$i,1);
       }
      
      } #End only one return
      } #End found definition 
    } #End turn into procedure

  } # End Treating connections

} 

sub stateOnNewPage
{ #Purpose: Insert pagebreaks before states and connection, see rule 'state and nextstate'(1)
  local($line) = "";
  local($statename) = "";
  local($notfound) = 1;
  local($pagedeclare) = 0;

  $lenght = @sdlfile;
  $i = 0;

  # Find the place in the CIF file header where the pages are declared
  while(($sdlfile[$i] =~ /(CIF ProcessDiagram)|(CIF Page)|(CIF Frame)/i))
  {$i++;
  }
  $pagedeclare = $i-1;


  # Search trough sdlfile, looking for states and connections
  while($i< @sdlfile)
  {
    if( $sdlfile[$i] =~ /^(state|connection) (\w+|\*)/i)
    {
      $statename = "$1_$2";
      if($statename eq "state_*")
      { print "Changed name on _*\n";
        $statename = "asterisk_state";
      }
      # print "checking $statename\n";

      # Search backwards in sdlfile, to see if a pagebreak has been declared since 
      # last endstate or endconnection
      $j = $i-1; $notfound = 1;
      while(!($sdlfile[$j] =~ /^(endstate|endconnection)/) && $notfound)
      { if($sdlfile[$j] =~ /^\/\* CIF CurrentPage/)
        { $notfound = 0; #print "$statename HAS a pagebreak\n";
        }
        else {$j--; #print ".";
             }
      }

      if($notfound) # Insert code for pagebreak
      { splice(@sdlfile,$j+1,0,"/* CIF CurrentPage $statename */\n"); 
        $i++; $lenght++;

        # Insert declaration of the new page in the CIF header
        splice(@sdlfile,$pagedeclare+1,0,"/* CIF Page $statename ($pageWidth,$pageHeight) */\n");
        splice(@sdlfile,$pagedeclare+2,0,"/* CIF Frame (0,0),($pageWidth,$pageHeight) */\n");
        $pagedeclare = $pagedeclare+2;
        $i=$i+2; #Skip two lines, since the declaration has moved everything downwards

         print "Inserted new page for $statename\n"; 
      } # End insert pagebreak

    } # End backtracking

    $i++;
  } # End searching through sdlfile

}


sub alignPages
{ # Prupose: To make state symbols appear in the upper left corner
  local($pageStart) = 0;

  $i = 0;
  print "aligning pages\n";

  # Search through sdlfile, check all pages
  while($i < @sdlfile)
  { if(($sdlfile[$i] =~ /\/\* CIF CurrentPage/i)
    && ($sdlfile[$i+1] =~ /\/\* CIF (State|Label)/i)) # Give up on the start page :-(
    # Page with state found
   { $i++;
     $sdlfile[$i] =~ /\/\* CIF (State|Label|Start) \((\d+),(\d+)\)/i;
     # Put the state symbol in the right place.
     # This might brake the lines to the symbol, this will be fixed by
     # resolvePageOverflow. Oops, there goes procedure independency...
     if($1 =~ /label/i) {$x = 350;} else {$x = 300;}
     if(($2 != $x) || ($3 != 100))
       { $sdlfile[$i]=~ s/\((\d+)/$x/e; # Substitute '(x' with the right x
         $sdlfile[$i]=~ s/(\d+)\)/100/; # Substitute 'y)' with 100
         $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/; # Put the parantheses back in
       }
    $pageStart = $i;
    $i++;
    #print "$sdlfile[$i]\n";
    # Extract coordinates for the first symbol, evaluate offset
    until($sdlfile[$i] =~ /^\/\* CIF/i && ($sdlfile[$i] !~ /(Line|Comment)/i))
      {$i++;}
    $sdlfile[$i] =~ /^\/\* CIF \w+ \((\d+),(\d+)\)/i;     
    $x = $1-300;
    $y = $2-250;
    print "line: $i x: $x y: $y $sdlfile[$i]";
    
    # Search through the page, alter all coordinates according to offset
    $i = $pageStart+1; # Jump back up to the line after state statement
    until($sdlfile[$i] =~ /^(endstate|endconnection)/i)
    { 
      # In some CIF statements, only the first (x,y) pair must be changed,
      # since the second (x,y) defines the size of the symbol.
      if($sdlfile[$i] =~ /\/\* CIF (Label|Join|Comment|Text)/i) 
      { 
        $sdlfile[$i]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
        $sdlfile[$i]=~ s/(\d+)\)/$1-$y/e; # Substitute 'y)' with y minus offset
        $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/; # Put the parantheses back in
        #print "Replaced only 1st x,y on line $i: $sdlfile[$i]";
      }

      elsif($sdlfile[$i] =~ /\/\* CIF/) 
      { $sdlfile[$i]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
        $sdlfile[$i]=~ s/(\d+)\)/$1-$y/ge; # Substitute 'y)' with y minus offset
        $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/g; # Put the parantheses back in
      }
      $i++;
    } # End aligning symbols

    # Adjust nextstates upwards if they are far below the previous symbol
    $i = $pageStart;

    until($sdlfile[$i] =~ /^(endstate|endconnection)/i)
    { 
     if($sdlfile[$i] =~ /^\/\* CIF NextState/i)
     {  #Search upwards to find the line to the nextstate
        $rightline = $i-1;
        until($sdlfile[$rightline] =~ /\/\* CIF Line/i)
        {$rightline--; }

       $sdlfile[$rightline] =~ /\/\* CIF Line \(\d+,(\d+)\),\(\d+,(\d+)\) \*\//;
       #Extract the two y-coordinates for the line
       #print "$sdlfile[$rightline]";
       #print "y1: $1 y2: $2\n";
       if($2-$1 != 50)
       { $newY = $1+50;
         $sdlfile[$rightline]=~ s/(\d+)\) \*\//$newY\) \*\//; #Adjust the second y-coordinate
         $sdlfile[$i]=~ s/(\d+)\) \*\//$newY\) \*\//;
       }#End moving misplaced nextstate
     } #End checking nextstate
     $i++;
    } #End checking page for misplaced nextstates

   
   } # End found page
    $i++;
  } # End searching through sdlfile
}


sub alignNextstates
{ #Purpose: Align nextstates on each page horizontally, see rule 'state and nextstate'(2)

  local(@statelines) = ();
  local($nextstates) = 0;
  local($largestY) = 0;
  local($line) = "";
  local($currentState) = "start";

  $i = 0;
  $lenght = @sdlfile;

print "Aligning nextstates\n";


while($i < @sdlfile)
{ @statelines = ();
  $nextstates = 0;


  # For each page put the linenumbers of nextstate symbols in @statelines,
  until($sdlfile[$i] =~ /^(\/\* CIF CurrentPage|endprocess|endprocedure)/i)
  { if(($sdlfile[$i] =~ /^nextstate/) && ($currentState ne "start"))
    {                                   # Don't move the nextstate in the start transition
      #print"$sdlfile[$i-1]";
      #print"$sdlfile[$i]\n";     
      $statelines[$nextstates] = $i;
      $nextstates++;
    }

    # Keep track of wich state we're in
    if($sdlfile[$i] =~ /^state (.+);/i)
    {$currentState = $1;
    }

    $i++;
  }

  # Compare the y-coordinates and put the largest in $largestY
  $largestY = 0;

  foreach $line (@statelines)
  { #print "find Y: $sdlfile[$line-1]\n";
    $sdlfile[$line-1] =~ /(\d+)\) \*\//;
    if($1 > $largestY) {$largestY = $1;}
  }
#  print "y: $largestY\n";

   # Substitute the y-coordinate for the nextstate symbols and the line
   # to them with $largestY
   foreach $line (@statelines)
   { $sdlfile[$line-1] =~ s/(\d+)\) \*\/$/$largestY\) \*\//;

     #Search upwards to find the line to the nextstate
     $rightline = $line-2;
     until($sdlfile[$rightline] =~ /\/\* CIF Line/i)
     {$rightline--; }
     $sdlfile[$rightline] =~ s/(\d+)\) \*\/$/$largestY\) \*\//;
     #print"$sdlfile[$rightline]";
     #print"$sdlfile[$line-1]\n";
   }  
  $i++; #Go past the pagebreak and into the next page
} #end searching through sdlfile
}

sub makeSignalTextExtension
{ # Purpose: Put the parameters to a signal in a text extension if necessary,
  # see rule 'signal parameters'
   $i = 0;
   local($parameters) = 0;
   local($signalLine) = 0;
   local($CIFstring) = "";
   local($extFound) = 0;
   local($signalname) = "";

  print "Checking signals for necessary text extentions\n";
  while($i < @sdlfile)
  {
    # If the signal has parameters, start checking it
    if($sdlfile[$i] =~ /^(output|input) (\w+)/i && !($sdlfile[$i] =~ /;/))
    { $signalname = $2;
      $parameters = 0; $extFound = 0;
      $signalLine = $i;

      # Count the parameters, every line beginning with a letter, except 'comment'
      until(($sdlfile[$i] =~ /(;|^\/\* CIF Comment)/i) || ($extFound == 1))
      { if($sdlfile[$i] =~ /^\(?\w+/ && !($sdlfile[$i] =~ /^comment/))
        { $parameters++;
	}
        if($sdlfile[$i] =~ /CIF TextExtension/i)
	{ $extFound = 1; print "$signalname HAS text extention\n";
        }
	$i++;
      }

      if($parameters > 2 && ($extFound == 0))
      { print "Added extension to signal $signalname\n";
        # Extract the coordinates of the signal symbol
        $sdlfile[$signalLine-1] =~ /\/\* CIF .+put \((\d+),(\d+)\)/;
        $x = $1; $y = $2;

        # Insert CIF code for a text extension and line rigt after the signal statement
        $CIFstring = sprintf("/* CIF TextExtension (%d,%d) Right */\n",$x+250,$y);
        splice(@sdlfile,$signalLine+1,0,$CIFstring); 
        $CIFstring = sprintf("/* CIF Line (%d,%d), (%d,%d) */\n",$x+250,$y+50,$x+200,$y+50);
        splice(@sdlfile,$signalLine+2,0,$CIFstring); 

	# Insert CIF code to end the text extension right before the semicolon
        splice(@sdlfile,$i+2,0,"/* CIF End TextExtension */\n"); 
                      # $i+2, since two lines have been inserted
        $i=$i+3;
      } # End make text extension

    } # End check signal statement
    $i++;
  } # End search through sdlfile

}

sub removeInvisibleJoins
{ # Purpose: Expand all invisible joins, remove the invisble labels.
  # See rule 'connections'

  local($joinName) = "";
  local($notFound) = 1;

 # Search trough sdlfile, expand all invisible joins
 print "Expanding invisible joins.\n"; 
 $i = 0;
 while($i< @sdlfile)
 { if($sdlfile[$i] =~ /^\/\* CIF Join Invisible/i)
   { $sdlfile[$i+1] =~ /join (\w+);/i;
     $joinName = $1;
     #print "Found invisible join $joinName at line ",$i+1,".\n";

     # Find the coordinates of the join
     if($sdlfile[$i-1] =~ /^\/\* CIF Line \((\d+),(\d+)/)
       {$joinLine = $i-1;  $x = $1-100; $y =$2+50; print "x: $x y:$y $sdlfile[$joinLine]";}
     elsif($sdlfile[$i+2] =~ /^\/\* CIF Line \((\d+),(\d+)/)
       {$joinLine = $i+2; $x = $1-100; $y =$2+50; print "x: $x y:$y $sdlfile[$joinLine]"; }
     else {print "Couldn't find coordinates!\n"; }

     # Search for the definition of the connection
     $j= 0; $notFound = 1;
     while(($j < @sdlfile) && $notFound)
     { if(($sdlfile[$j] =~ /^$joinName/i) && ($sdlfile[$j-1] =~ /^\/\* CIF Label Invisible/i))
          {$notFound = 0; print "Found $sdlfile[$j]";}
       else {$j++;}          
     } # End finding definition
     #print "Definition at line $j: $sdlfile[$j]";

    
     # Remove the join
     #print "deleting: $sdlfile[$i]";
     splice(@sdlfile,$i,1);
     #print "deleting: $sdlfile[$i]";
     splice(@sdlfile,$i,1);
     # Make the line to the expanded symbols
     $orgY = $y-50; $tmp = $x+100;
     $sdlfile[$joinLine] = "/* CIF Line ($tmp,$orgY),($tmp,$y) */\n";

     # Find the coordinates of the first symbol after the invisible join, evaluate offset
     $sdlfile[$j+1] =~ /\((\d+),(\d+)\) \*\/$/;
     $x = $1 - $x; $y = $2 - $y; print "offset: $x, $y\n";

     # Expand the connection
     $j++; print "Expanding $joinName:\n";
     until($sdlfile[$j+1] =~ /^\/\* CIF Input/i || $sdlfile[$j-1] =~ /^(endstate|endconnection)/i)
     { splice(@sdlfile,$i,0,$sdlfile[$j]); 
       if($j>$i) {$j++;}
  
       #Correct the coordiantes in the inserted line
       # In a CIF label or Join statement, only the first (x,y) pair must be changed,
         # since the second (x,y) defines the size of the symbol.
         if($sdlfile[$i] =~ /\/\* CIF (Label|Join|Comment|Text) /i)
         { $sdlfile[$i]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
           $sdlfile[$i]=~ s/(\d+)\)/$1-$y/e; # Substitute 'y)' with y minus offset
           $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/; # Put the parantheses back in
         }

         elsif($sdlfile[$i] =~ /\/\* CIF/) 
         { $sdlfile[$i]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
           $sdlfile[$i]=~ s/(\d+)\)/$1-$y/ge; # Substitute 'y)' with y minus offset
           $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2\)/g; # Put the parantheses back in
         }
       #print "$sdlfile[$i]";
        $i++; $j++;
       } # End expanding connection
    
   } # End found invisible join
 $i++;
 } # End expanding invisible joins

 #Search trough sdlfile, remove all invisible labels
 $i = 0;
 while($i< @sdlfile)
 { if ($sdlfile[$i] =~ /^\/\* CIF Label Invisible/i)
   {  print "Removing label $sdlfile[$i+1]";
      splice(@sdlfile,$i,1);
      splice(@sdlfile,$i,1);
   }

 $i++;
 } # End deleting labels

} # End sub


sub insertTextExtensions
{ # Purpose: Warn of missing TO/FROM statements/comments, insert dummy comments in the SDL,
  # see rule 'source and destination'


  $i = 0;
  local($found) = 0;
  local($commentString) = "";
  local($signalname) = "";
  local($direction) = "";

  print "Checking TO/FROM-statements on signals\n";
  while($i< @sdlfile)
  { $sdlfile[$i]; $i++;

    # If a signal statement is found, extract the signal name and coordinates
    if($sdlfile[$i] =~ /^\/\* CIF (in|out)put \((\d+),(\d+)\)/i)
    { $direction = $1; $x = $2; $y = $3;
      #print "dir: $direction\n";
      $sdlfile[$i+1] =~ /put (\w+)/;
      $signalname = $1;
      $found = 0;

      # Check if the signal has a TO/FROM-statement or comment
      until(($sdlfile[$i] =~ /;$/) || $found)
      { $i++;
        if($sdlfile[$i] =~ /^(comment '(TO|FROM)|TO|VIA)/i)
        {$found = 1;}
      }
 
      # If the signal has no TO/FROM statement/comment, insert a comment
      if(!($found)) 
      {  
         if($sdlfile[$i] =~ /^$directionput/) 
         # If the semicolon is on the same line as the signal name

	  { $sdlfile[$i] =~ s/;//; 
            $i++;
            splice(@sdlfile,$i,0,";\n"); # Put the semicolon on the next line
          }
        
        if($direction =~ /in/i)
        { $direction = "FROM";}
        else {$direction = "TO";}

        # Insert the CIF code for the comment symbol, a line and the text
	$commentString = sprintf("/* CIF Comment (%d,%d) Right */\n",$x+250,$y);
        splice(@sdlfile,$i,0,$commentString);
        $commentString = sprintf("/* CIF Line (%d,%d), (%d,%d) Dashed */\n",$x+250,$y,$x+200,$y);
        splice(@sdlfile,$i+1,0,$commentString);
        $commentString = "comment '$direction: ?'\n";
        splice(@sdlfile,$i+2,0,$commentString);
 
        print "Warning: signal $signalname has no $direction-statement\n";
        #print "Added dummy $direction-statement to $signalname\n";

      } # End insert comment
    } # End searching through signal statement
  } # End searching through sdlfile
}

sub warnBranchOnDecision
{ # Purpose: Warn on decisions in the SDL, see rule 'control flow'


  $i = 0;
  local($currentState);

  while($i< @sdlfile)
  { $line = $sdlfile[$i]; $i++;

    # Keep track of wich state we're in
    if($line =~ /^state (.+);/i)
    {$currentState = $1;
    }

    if($line =~ /decision (.+);/i)
    { print "Warning: in state $currentState, the process branches on decision: $1\n";
    }
  }
}


sub warnShortNames
{  # Purpose: Warn on short names in the SDL, see rule 'meaningful names'


  $i = 0;

  while($i< @sdlfile)
  { $line = $sdlfile[$i]; $i++;
    if($line =~ /(DCL|SIGNAL) (\w+)/i)
    {  $name=$2; $len = length($2);
       if($len < 5)
	{ if($1 eq "DCL") { print "Warning: variable $name has a short name\n";}
          if($1 eq "SIGNAL") { print "Warning: signal $name has a short name\n";}
        }
    } # End check declaration
  } # End search through sdlfile
}

sub resolvePageOverflow
{ # Purpose: Make sure there is enogh horizontal space on each page, if not
  # create new pages.

  local($stateName) = "";
  local($pageName) = "";
  local($rightX) = 0;
  local($newPages) = 0;
  local($flowsUsed) = 0;
  local($startTransition) = 0;
  local($spaceNeeded) = 0;
  local($isState) = 1;
  local($lastName) = "";

  print "Checking horizontal spacing.\n";
  $i = 0;

while($i< @sdlfile)
{ if($sdlfile[$i] =~ /^\/\* CIF CurrentPage (\w+)/i)
  { $pageName = $1; $lastName = $pageName;

    until($sdlfile[$i] =~ /^\/\* CIF (State|Label)/i)
      {$i++;}

   if($sdlfile[$i] =~ /^\/\* CIF (State|Label) \((\d+),(\d+)/i)
      {if($1 eq "State"){$isState = 1; $statePosX = $2+100; $statePosY = $3+100;}
       if($1 eq "Label"){$isState = 0; $statePosX = $2; $statePosY = $3+100;}
      }  

    if($sdlfile[$i+1] =~ /^(state|connection) (\w+)/i)
      {$stateName = $2;}

    $flowsUsed = 0;
    $newPages = 1;
    $i++;

  while($sdlfile[$i] !~ /^\/\* CIF CurrentPage/i && $i < @sdlfile)
  {


    if($sdlfile[$i] =~ /^(nextstate|join)/)
      { # Check that it's not the start transition
	$j = $i; $startTransition = 0;
        while(($sdlfile[$j] !~ /^(state|connection)/i) && !$startTransition)
	{ if($sdlfile[$j] =~ /^start/i)
	  {$startTransition = 1; #print "Is in start Transition?\n";
          }
          $j--;
        } # End check for start transition
        if(!$startTransition)
          {$flowsUsed++;}
      }
  
    if($sdlfile[$i] =~ /^(input|save)/i)
    { $spaceNeeded = 0;
      if($sdlfile[$i-1] =~ /^\/\* CIF (Input|Save) \((\d+),(\d+)/)
      {
        $symbolX = $2; $symbolY = $3; print "$symbolX $symbolY $sdlfile[$i]";
        if($1 =~ /save/i) {$spaceNeeded++;}
      }
      else {print "Couldn't find symbolX in line ",$i-1,": $sdlfile[$i-1]";}

      # Check space needed by the flowline
      $j = $i+1;
      while($sdlfile[$j] !~ /^(input|endstate|endconnection|save)/i)
      { if($sdlfile[$j] =~ /^(nextstate|join)/i) {$spaceNeeded++;}
        $j++;
      }
       print "Space: $spaceNeeded used: $flowsUsed\n";
      if($spaceNeeded+$flowsUsed> $flowsPerPage)
      { # Create new page
        $newPages++;  $flowsUsed = 0;
        print "Created new page $pageName\part$newPages\n";
        if($isState) 
        { splice(@sdlfile,$i-2,0,"/* CIF End State */\n"); 
          $i++;
	  splice(@sdlfile,$i-2,0,"endstate;\n"); 
          $i++;
	  splice(@sdlfile,$i-2,0,"/* CIF CurrentPage $pageName\part$newPages */\n"); 
          $i++;
          splice(@sdlfile,$i-2,0,"/* CIF State (300,100) */\n");
          $i++;
          splice(@sdlfile,$i-2,0,"state $stateName;\n");
          $i++; 
       }
        else 
	{ splice(@sdlfile,$i-2,0,"/* CIF End Label */\n"); 
          $i++;
	  splice(@sdlfile,$i-2,0,"endconnection;\n"); 
          $i++;
	  splice(@sdlfile,$i-2,0,"/* CIF CurrentPage $pageName\part$newPages */\n"); 
          $i++;
	  splice(@sdlfile,$i-2,0,"/* CIF Label (350,100) (100,100) */\n"); 
          $i++;
          splice(@sdlfile,$i-2,0,"connection $stateName;\n");
          $i++; 
	}

        #$i++; 
        $statePosX = 400; $statePosY = 200;
 
        # Find the place in the CIF file header where the pages are declared
        $pagedeclare = 0;
	while(($sdlfile[$pagedeclare] !~ /CIF Page $lastName/i))
        {$pagedeclare++;
        }

        # Insert declaration of the new page in the CIF header
        splice(@sdlfile,$pagedeclare+2,0,"/* CIF Page $pageName\part$newPages ($pageWidth,$pageHeight) */\n");
        splice(@sdlfile,$pagedeclare+3,0,"/* CIF Frame (0,0),($pageWidth,$pageHeight) */\n");
        $pagedeclare = $pagedeclare+2;
        $i=$i+2; #Skip two lines, since the declaration has moved everything downwards
        $lastName = "$pageName\part$newPages";
      }

     #Check horizontal alignment
     $rightX = $flowsUsed * $flowSpacing + 300; print "RightX: $rightX\n";
     if($rightX != $symbolX) 
     { # Move the flowline to the right x-coordinate
       
      #Check the line from the state symbol to the input symbol
      if($sdlfile[$i-2] =~ /CIF Line \((\d+),(\d+)/i)
        { unless($1 == $statePosX && $2 == statePosY)
	  {$tmp = sprintf("/* CIF Line (%d,%d),(%d,%d),(%d,%d),(%d,%d) */\n",$statePosX,$statePosY,$statePosX,$statePosY+25,$rightX+100,$statePosY+25,$rightX+100,$symbolY);
           splice(@sdlfile,$i-2,1,$tmp); #print "$tmp";
          }
          #print "$1 $2";
        }
       else {print "Couldn't find line to symbol in $sdlfile[$i-2]";}
 
       # Evaluate offset
       $x = $symbolX- $rightX;
       print "Moving a flowline in $stateName $x pixels to the left\n";
       print "at line $i : $sdlfile[$i]";
       $i--; # Step one line up to start with the CIF signal 
       $startDecide = $i; $flowsDecide = $flowsUsed;
       while($sdlfile[$i+1] !~ /^\/\* CIF (Input|Save)/i && $sdlfile[$i] !~ /^(endstate|endconnection)/i)
       {
         #Correct the x-coordiantes in the flowline
         # In a CIF label or Join statement, only the first x must be changed,
         # since the second x defines the size of the symbol.
         if($sdlfile[$i] =~ /\/\* CIF (Label|Join|Comment|Text) /i)
         { $sdlfile[$i]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
           $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2/; # Put the parantheses back in
         }

         elsif($sdlfile[$i] =~ /\/\* CIF/) 
         { $sdlfile[$i]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
           $sdlfile[$i]=~ s/(\d+),(\d+)/\($1,$2/g; # Put the parantheses back in
         }
	  if($sdlfile[$i] =~ /^(nextstate|join)/) {$flowsUsed++;} 
        $i++; 
        } # End adjusting x-coordinates

     } # End fix alignment
    } # End check input signal

    if($spaceNeeded > 1)
    {  # Check spacing inside decisions
       $j = $startDecide;
      while($sdlfile[$j+1] !~ /^\/\* CIF (Input|Save)/i && ($sdlfile[$j+1] !~ /(endstate|endconnection)/i) && $j < @sdlfile)
      #|(endstate|endconnection))/i) 
      {
        if($sdlfile[$j] =~ /^(join|nextstate)/i &&
          ($sdlfile[$j+1] =~ /CIF Answer/i) &&
          ($sdlfile[$j+2] =~ /\((\d+),(\d+)\) \*\//))
        {
         $flowsDecide++;
	  $x = $1 -100; 
          print "Inside! x = $x, flows = $flowsDecide, $sdlfile[$j+2]";
          #Check horizontal alignment
          $rightX = $flowsDecide * $flowSpacing + 300; print "RightX: $rightX\n";
      if($x != $rightX) 
      { # Evaluate offset
        $x = $x - $rightX;
        print "Moving a flowline Inside a decision in $stateName $x pixels to the left\n";
        print "at line $j : $sdlfile[$j]";
  
       while($sdlfile[$j+1] !~ /^(join|nextstate)/i)
       {
         #Correct the x-coordiantes in the flowline
         # In a CIF label or Join statement, only the first x must be changed,
         # since the second x defines the size of the symbol.
         if($sdlfile[$j] =~ /\/\* CIF (Label|Join|Comment|Text) /i)
         { $sdlfile[$j]=~ s/\((\d+)/$1-$x/e; # Substitute '(x' with x minus offset
           $sdlfile[$j]=~ s/(\d+),(\d+)/\($1,$2/; # Put the parantheses back in
         }

         elsif($sdlfile[$j] =~ /\/\* CIF/) 
         { $sdlfile[$j]=~ s/\((\d+)/$1-$x/ge; # Substitute '(x' with x minus offset
           $sdlfile[$j]=~ s/(\d+),(\d+)/\($1,$2/g; # Put the parantheses back in
         }
	 
        $j++; 
        } # End adjusting x-coordinates
	} # End x != rightX
      } # End found a nextstate/join
        $j++;	   
     } # End searching the flowline
    } # End checking inside decisions 
     
    $i++;
   } # End search through page

  } # End check page
  else {$i++;}
} # End search through sdlfile
} # End procedure

sub removeEmptyPages
{ # Purpose: Remove pages that have become empty after deletion of connections
  $i = 0;

  while($i < @sdlfile)
  { if($sdlfile[$i+1] =~ /^\/\* CIF currentPage/i &&
      $sdlfile[$i] =~ /^\/\* CIF currentPage (\w+)/i)
      { # Delete the pagebreak
        $pageName = $1;
        print "At line: $i Deleting pagebreak $pageName\n";
        splice(@sdlfile,$i,1);
       } 
      $i++;
  } # End removing unnecessary pagebreaks

  # Check if the declared pages are in fact used
  $i = 2;
 
  while($sdlfile[$i] =~ /^\/\* CIF (Frame|Page)/i)
  { if($sdlfile[$i] =~ /^\/\* CIF Page (\w+)/i)
    { $pageName = $1; #print "Checking page $pageName\n";
      $inUse = 0;
      $j = $i;

      while(($j < @sdlfile) && ($inUse == 0))
      { if($sdlfile[$j] =~ /^\/\* CIF currentPage $pageName/i)
	{$inUse = 1;}
        $j++; 
      }
     
      # If not in use, Delete the declaration
      if($inUse == 0)
      {  splice(@sdlfile,$i,1);    
         splice(@sdlfile,$i,1);
         print "Deleted declaration of page $pageName\n";
      }

     } # End chech declaration
    $i++;
  } # End removing unused declarations
}
