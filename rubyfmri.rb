#!/usr/bin/env ruby
# the Dicom folder has to have the number of volumes in the name ex: Hand_80
# Modules required:
require 'rubygems'
require 'dcm2nii-ruby'
require 'fsl-ruby'
require 'narray'
require 'nifti'
require 'chunky_png'
require 'optparse'
require 'prawn'
require 'find'

options = {}
option_parser = OptionParser.new do |opts|

  opts.on("-f DICOMDIR", "The DICOM directory") do |dicomdir|
    options[:dicomdir] = dicomdir
  end

  opts.on("-o OUTPUTDIR", "The output directory") do |outputdir|
    options[:outputdir] = outputdir
  end
  
  opts.on("-z ZTHRESHOLD", 'The Z threshold for run feat') do |zthreshold|
          options[:zthreshold]=zthreshold
  end

  #opts.on("-s", "--studyInfo patfName,patlName,patId,studyDate, accessionNo", Array, "The study information for the report") do |study|
   #   options[:study] = study
  #end
  
  opts.on("-b betormask", 'chose 0 to bet 1 to mask') do |betormask|
          options[:betormask]=betormask
  end

end

option_parser.parse!

LabelColor = ChunkyPNG::Color.rgb(255,0,0)
#patfName = options[:study][0]
#patlName = options[:study][1]
#patId = options[:study][2]
#studyDate = options[:study][3]
#accessionNo = options[:study][4]

dirnames = Dir.entries(options[:dicomdir]).select {|entry| File.directory? File.join(options[:dicomdir],entry) and !(entry =='.' || entry == '..') }
def read_nifti(nii_file)
  NIFTI::NObject.new(nii_file, :narray => true).image.to_i
end


#### END METHODS ####

beginning_time = Time.now

# CONVERT DICOM TO NIFTI
original_image=1
output_vol=1
dirnames.each do |name|
        pathname="#{options[:dicomdir]}/#{name}"
        outputpath="#{options[:outputdir]}/#{name}"
        Dir.mkdir(File.join(options[:outputdir], name), 0700)

        dn = Dcm2nii::Runner.new(pathname,{anonymize: false, reorient_crop:false, reorient:false, output_dir:outputpath})
         # creates an instance of the DCM2NII runner
         dn.command # runs the utility
        mostrar= dn.get_nii
      
         if name=="VOL_AX"
         original_image = dn.get_nii # Returns the generated nifti file
      
         output_vol=outputpath
         end
         
end

# PERFORM BRAIN EXTRACTION
if options[:betormask]==0
bet = FSL::BET.new(original_image, output_vol, {fi_threshold: 0.5, v_gradient: 0})
bet.command
bet_image = bet.get_result
else
  brain_image1="#{output_vol}/brainmask.nii.gz "
  niiimage="#{output_vol}/#{original_image} "
 
  `standard_space_roi niiimage brain_image1 -b`
  
  bet = FSL::BET.new(brain_image1, output_vol, {fi_threshold: 0.15, v_gradient: 0})
  bet.command
  bet_image = bet.get_result
  
end
  


#FEAT command line
dirnames.delete('VOL_AX')
nvolume=dirnames[0].scan(/\d+/)
nvolumes=nvolume[0].to_i
nifftifile= Dir.glob("#{options[:outputdir]}/#{dirnames[0]}/*.gz")
nifftifile=nifftifile[0];
puts 'niftifile'
puts nifftifile
`cp /Users/catalinabustamante/Documents/codigo/fMRI/design_tem.fsf #{options[:outputdir]}/#{dirnames[0]}`
path="#{options[:outputdir]}/#{dirnames[0]}/design_tem.fsf"
design = File.read(path) 
replace=design.gsub(/set fmri\(([npts)]+)\) 80/,"set fmri(npts) #{nvolumes}")
replace = replace.gsub(/set fmri\(([z_thresh)]+)\) 2.3/, "set fmri(z_thresh) #{options[:zthreshold]}")
replace = replace.gsub(/set feat_files\(([1)]+)\) pathf/, "set feat_files(1) \"#{nifftifile}\"")
replace = replace.gsub(/set highres_files\(([1)]+)\) paths/, "set highres_files(1) \"#{bet_image}\"")
File.open(path, "w") {|file| file.puts replace}
`feat #{path}`


end_time = Time.now
puts "Time elapsed #{(end_time - beginning_time)} seconds"