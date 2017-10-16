require 'rubygems'
require 'dcm2nii-ruby'
require 'fsl-ruby'
require 'narray'
require 'nifti'
require 'chunky_png'
require 'optparse'
require 'prawn'
require 'find'
require 'fileutils'

options = {}
option_parser = OptionParser.new do |opts|

  opts.on("-f DICOMDIR", "The DICOM directory") do |dicomdir|
    options[:dicomdir] = dicomdir
  end
end  
	
	option_parser.parse!

	inidicom=options[:dicomdir]
	
	dirname= Dir.entries(inidicom).select {|entry| File.directory? File.join(inidicom,entry) and !(entry =='.' || entry == '..') }
	
  
dirname.each do |dn|
  thpathg= Dir.glob("#{inidicom}/#{dn}/*.feat/hr")
  puts thpathg
  thpath="#{thpathg[0]}/thresh_zstat1.nii.gz"
	puts thpath
 
  thpath_reg="#{thpathg[0]}/thresh_zstat1_reg.nii.gz"
  puts thpath_reg
	matriz="/Users/catalinabustamante/Documents/PACIENTES/fMRI/Leshaw_Nicholas_Daniel/LESHAW_NICHOLAS_DANIEL/00040004926_1_1101_PIE_DER_20140515/LESHAW_NICHOLAS_DANIEL_20140515_00040004926_1_1101_PIE_DER_SENSE_PIE_DER.feat/hr/background_reg.mat"
  puts matriz
	
	flair="/Users/catalinabustamante/Documents/PACIENTES/fMRI/Leshaw_Nicholas_Daniel/LESHAW_NICHOLAS_DANIEL/00040004926_1_401_FL_VISTA_20140515/LESHAW_NICHOLAS_DANIEL_20140515_00040004926_1_401_FL_VISTA_SENSE_FL_VISTA.nii"
	
	puts flair
	`flirt -in #{thpath} -ref #{flair} -out #{thpath_reg} -init #{matriz} -applyxfm`
end