/*
* Copyright (c) 2012 The Broad Institute
* 
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without
* restriction, including without limitation the rights to use,
* copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the
* Software is furnished to do so, subject to the following
* conditions:
* 
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
* 
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
* OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
* NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
* HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
* THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

package org.broadinstitute.sting.queue.qscripts

import org.broadinstitute.sting.queue.QScript
import org.broadinstitute.sting.queue.extensions.gatk._

class HardFilter extends QScript {
    // Create an alias 'qscript' to be able to access variables in the HardFilter.
    // 'qscript' is now the same as 'HardFilter.this'
    qscript =>

    // Required arguments.  All initialized to empty values.
    @Input(doc="The reference file", shortName="R", required=true)
    var referenceFile: File = _

    @Input(doc="Raw vcf file", shortName="V")
    var rawVCF: File =_

    @Input(doc="Output core filename.", shortName="O", required=true)
    var out: File = _
    
    @Argument(doc="Maximum amount of memory", shortName="mem", required=true)
    var maxMem: Int = _

    @Argument(doc="Number of scatters", shortName="nsc", required=true)
    var numScatters: Int = _

    // filteroptions -> default: best-practices value
    @Argument(doc="A optional list of SNPfilter names.", shortName="snpFilter", required=false)
    var snpFilterNames: List[String] = List("LowQualityDepth","MappingQuality","StrandBias","HaplotypeScoreHigh","MQRankSumLow","ReadPosRankSumLow" )
  
    @Argument(doc="An optional list of filter expressions.", shortName="snpFilterExpression", required=false)
    var SNPfilterExp: List[String] = List ("QD < 2.0", "MQ < 40.0", "FS > 60.0", "HaplotypeScore > 13.0", "MQRankSum < -12.5", "ReadPosRankSum < -8.0")
    
    @Argument(doc="A optional list of INDEL filter names.", shortName="indelFilter", required=false)
    var indelFilterNames: List[String] = List("LowQualityDepth","StrandBias","ReadPosRankSumLow" ) 
      
    @Argument(doc="An optional list of INDEL filter expressions.", shortName="indelFilterExpression", required=false)
    var INDELfilterExp: List[String] = List ("QD < 2.0", "FS > 200.0", "ReadPosRankSum < -20.0") 

    // This trait allows us set the variables below in one place and then reuse this trait on each CommandLineGATK function below.
    trait HF_Arguments extends CommandLineGATK {
	this.reference_sequence = referenceFile
	this.memoryLimit = maxMem
    }

    def script() {
	val selectSNP = new SelectVariants with HF_Arguments
	selectSNP.V = rawVCF
	selectSNP.selectType :+= org.broadinstitute.variant.variantcontext.VariantContext.Type.SNP
	selectSNP.selectType :+= org.broadinstitute.variant.variantcontext.VariantContext.Type.NO_VARIATION
	selectSNP.out = qscript.out + ".raw_SNPS.vcf"
    
	val selectINDEL = new SelectVariants with HF_Arguments
        selectINDEL.V = rawVCF
	selectINDEL.selectType :+= org.broadinstitute.variant.variantcontext.VariantContext.Type.INDEL
	selectINDEL.out = qscript.out + ".raw_INDELS.vcf"

        val SNPfilter = new VariantFiltration with HF_Arguments
	SNPfilter.scatterCount = numScatters
	SNPfilter.V = rawVCF
	SNPfilter.out = qscript.out + ".filtered_SNPS.vcf"
	SNPfilter.filterExpression = SNPfilterExp 
	SNPfilter.filterName = snpFilterNames

	val INDELfilter = new VariantFiltration with HF_Arguments
	INDELfilter.scatterCount = numScatters
	INDELfilter.V = rawVCF
	INDELfilter.out = qscript.out + ".filtered_INDELS.vcf"
	INDELfilter.filterExpression = INDELfilterExp
	INDELfilter.filterName = indelFilterNames
	
	val CombineVars = new CombineVariants with HF_Arguments
	CombineVars.V :+= SNPfilter.out
	CombineVars.V :+= INDELfilter.out
	CombineVars.out = qscript.out + ".filtered_VARIANTS.vcf"

	add(selectSNP, selectINDEL, SNPfilter, INDELfilter, CombineVars)
     }
}