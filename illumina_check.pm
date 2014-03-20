#!/usr/bin/perl -w

##################################################################################################################################################
###This script is designed check the final output of the illumina pipeline
###
###
###Author: R.F.Ernst
###Latest change: skeleton
###TODO:
##################################################################################################################################################

package illumina_check;

use strict;
use POSIX qw(tmpnam);

sub runCheck {
    my $configuration = shift;
    my %opt = %{readConfiguration($configuration)};
    my $runName = (split("/", $opt{OUTPUT_DIR}))[-1];
    my $doneFile;
    my @runningJobs;
    
    ### Create bash file
    my $jobID = get_job_id();
    my $bashFile = "$opt{OUTPUT_DIR}/jobs/check_".get_job_id().".sh";
    open (BASH,">$bashFile") or die "ERROR: Couldn't create $bashFile\n";
    print BASH "\#!/bin/sh\n . $opt{CLUSTER_PATH}/settings.sh\n\n";
    
    ### Log file
    my $logFile = "$opt{OUTPUT_DIR}/logs/check.log";
    print BASH "failed=false \n";
    print BASH "echo \"Check and cleanup for run: $runName \" >>$logFile\n\n";
    
    ### Check sample steps
    foreach my $sample (@{$opt{SAMPLES}}){
	print BASH "echo \"Sample: $sample\" >>$logFile\n";
	if($opt{PRESTATS} eq "yes"){
	    $doneFile = $opt{OUTPUT_DIR}."/$sample/QCStats/$sample.done";
	    print BASH "if [ -f $doneFile ]; then\n";
	    print BASH "\techo \"\t PreStats: done \" >>$logFile\n";
	    print BASH "else\n";
	    print BASH "\techo \"\t PreStats: failed \">>$logFile\n";
	    print BASH "\tfailed=true\n";
	    print BASH "fi\n";
	}
	if($opt{MAPPING} eq "yes"){
	    $doneFile = $opt{OUTPUT_DIR}."/$sample/mapping/$sample\_dedup.done";
	    print BASH "if [ -f $doneFile ]; then\n";
	    print BASH "\techo \"\t Mapping: done \" >>$logFile\n";
	    print BASH "else\n";
	    print BASH "\techo \"\t Mapping: failed \">>$logFile\n";
	    print BASH "\tfailed=true\n";
	    print BASH "fi\n";
	}
	if($opt{INDELREALIGNMENT} eq "yes"){
	    $doneFile = $opt{OUTPUT_DIR}."/$sample/mapping/$sample\*_realigned.done";
	    print BASH "if [ -f $doneFile ]; then\n";
	    print BASH "\techo \"\t IndelRealignment: done \" >>$logFile\n";
	    print BASH "else\n";
	    print BASH "\techo \"\t IndelRealignment: failed \">>$logFile\n";
	    print BASH "\tfailed=true\n";
	    print BASH "fi\n";
	}
	if($opt{BASEQUALITYRECAL} eq "yes"){
	    $doneFile = $opt{OUTPUT_DIR}."/$sample/mapping/$sample\*_recalibrated.done";
	    print BASH "if [ -f $doneFile ]; then\n";
	    print BASH "\techo \"\t BaseRecalibration: done \" >>$logFile\n";
	    print BASH "else\n";
	    print BASH "\techo \"\t BaseRecalibration: failed \">>$logFile\n";
	    print BASH "\tfailed=true\n";
	    print BASH "fi\n";
	}
	print BASH "echo \"\">>$logFile\n\n"; ## empty line between samples
	
	## Running jobs
	if ( $opt{RUNNING_JOBS}->{$sample} ){
	    push( @runningJobs, @{$opt{RUNNING_JOBS}->{$sample}} );
	}
    }
    
    ### Check run steps
    if($opt{POSTSTATS} eq "yes"){
	$doneFile = $opt{OUTPUT_DIR}."/tmp/postStats.done";
	print BASH "if [ -f $doneFile ]; then\n";
	print BASH "\techo \"PostStats: done \" >>$logFile\n";
	print BASH "else\n";
	print BASH "\techo \"PostStats: failed \">>$logFile\n";
	print BASH "\tfailed=true\n";
	print BASH "fi\n";
    }
    if($opt{VARIANT_CALLING} eq "yes"){
	$doneFile = $opt{OUTPUT_DIR}."/tmp/variantCalling.done";
	print BASH "if [ -f $doneFile ]; then\n";
	print BASH "\techo \"VariantCalling: done \" >>$logFile\n";
	print BASH "else\n";
	print BASH "\techo \"VariantCalling: failed \">>$logFile\n";
	print BASH "\tfailed=true\n";
	print BASH "fi\n";
    }
    if($opt{FILTER_VARIANTS} eq "yes"){
	$doneFile = $opt{OUTPUT_DIR}."/tmp/filterVariants.done";
	print BASH "if [ -f $doneFile ]; then\n";
	print BASH "\techo \"FilterVariants: done \" >>$logFile\n";
	print BASH "else\n";
	print BASH "\techo \"FilterVariants: failed \">>$logFile\n";
	print BASH "\tfailed=true\n";
	print BASH "fi\n";
    }
    if($opt{ANNOTATE_VARIANTS} eq "yes"){
	$doneFile = $opt{OUTPUT_DIR}."/tmp/annotateVariants.done";
	print BASH "if [ -f $doneFile ]; then\n";
	print BASH "\techo \"AnnotateVariants: done \" >>$logFile\n";
	print BASH "else\n";
	print BASH "\techo \"AnnotateVariants: failed \">>$logFile\n";
	print BASH "\tfailed=true\n";
	print BASH "fi\n";
    }
    
    ### Check failed variable
    print BASH "echo \"\">>$logFile\n\n"; ## empty line after stats
    print BASH "if [ \"\$failed\" = true  ]; then\n";
    print BASH "\techo \"One or multiple step(s) of the pipeline failed. \" >>$logFile\n";
    print BASH "else\n";
    print BASH "\techo \"The pipeline completed successfully. \">>$logFile\n";
    print BASH "fi\n";
    
    #Start main bash script
    my $logDir = $opt{OUTPUT_DIR}."/logs";
    if (@runningJobs){
	system "qsub -q $opt{CHECKING_QUEUE} -pe threaded $opt{CHECKING_THREADS} -o $logDir -e $logDir -N check_$jobID -hold_jid ".join(",",@runningJobs)." $bashFile";
    } else {
	system "qsub -q $opt{CHECKING_QUEUE} -pe threaded $opt{CHECKING_THREADS} -o $logDir -e $logDir -N check_$jobID $bashFile";
    }
}

sub readConfiguration{
    my $configuration = shift;	
    my %opt;

    foreach my $key (keys %{$configuration}){
	$opt{$key} = $configuration->{$key};
    }

    if(! $opt{CHECKING_QUEUE}){ die "ERROR: No CALLING_QUEUE found in .conf file\n" }
    if(! $opt{CHECKING_THREADS}){ die "ERROR: No CALLING_THREADS found in .conf file\n" }
    if(! $opt{OUTPUT_DIR}){ die "ERROR: No OUTPUT_DIR found in .conf file\n" }

    return \%opt;
}

############
sub get_job_id {
    my $id = tmpnam();
    $id=~s/\/tmp\/file//;
    return $id;
}
############

1;