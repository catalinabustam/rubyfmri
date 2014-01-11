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
require 'fileutils'

options = {}
option_parser = OptionParser.new do |opts|

  opts.on("-f DICOMDIR", "The DICOM directory") do |dicomdir|
    options[:dicomdir] = dicomdir
  end

  #opts.on("-o OUTPUTDIR", "The output directory") do |outputdir|
   # options[:outputdir] = outputdir
  #end
  
  #opts.on("-z ZTHRESHOLD", 'The Z threshold for run feat') do |zthreshold|
   #       options[:zthreshold]=zthreshold
  #end
  
  
  opts.on("-b BETORMASK", 'SELECT BET OR BRAIN MASK') do |betormask|
          options[:betormask]=betormask
  end

  #opts.on("-s", "--studyInfo patfName,patlName,patId,studyDate, accessionNo", Array, "The study information for the report") do |study|
   #   options[:study] = study
  #end

end

option_parser.parse!

inidicom=options[:dicomdir]
betormask=options[:betormask]

#zthreshold=options[:zthreshold]
nvolumes=120
zthreshold=2.3


# CAMBIAR EL NOMBRE DE LA CARPETA QUE CONTIENE LOS DICOMS
dirname= Dir.entries(inidicom).select {|entry| File.directory? File.join(inidicom,entry) and !(entry =='.' || entry == '..') }

completepath="#{inidicom}/#{dirname[0]}"
newname="#{inidicom}/0DICOM"

FileUtils.mv completepath, newname

#CONVERT DICOM TO NIFTI
#SE CORRE EL COMANDO DE MCVERTER

`mcverter -f fsl -x -d -n -o #{inidicom} #{inidicom}`

dirnewname= Dir.entries(inidicom).select {|entry| File.directory? File.join(inidicom,entry) and !(entry =='.' || entry == '..') }

dirniiname=dirnewname[1]

dirniipath="#{inidicom}/#{dirniiname}"
dirniilist=Dir.entries(dirniipath).select {|entry| File.directory? File.join(dirniipath,entry) and !(entry =='.' || entry == '..') }

volaxfolder=1
flair=1
dirniilist.each do |name|
  
  isvol=name.scan("VOL_AX")
  
  if isvol.empty?
    else
      volaxfolder=name
  end
  
  isflair=name.scan("FLAIR")
  
  if isflair.empty?
  else
    flair=name
  end
end

puts volaxfolder
dirniilist.delete(volaxfolder)
dirniilist.delete(flair)

volaxa=Dir["#{dirniipath}/#{volaxfolder}/*.nii"]
volaxf="#{dirniipath}/#{volaxfolder}"
volax=volaxa[0]
newvolax="#{dirniipath}/#{volaxfolder}/volax.nii"
FileUtils.mv volax, newvolax


flair=Dir["#{dirniipath}/#{flair}/*.nii"]
flairdir=Dir["#{dirniipath}/#{flair}"]
flair_reg="#{flairdir}/flair_reg.nii"
#### END METHODS ####

beginning_time = Time.now



if betormask=="1"
  # PERFORM BRAIN EXTRACTION
  puts "CON BET"
  bet = FSL::BET.new(newvolax, volaxf, {fi_threshold: 0.45, v_gradient: 0})
  bet.command
  bet_image = bet.get_result

else
  puts "CON MASK"
  mask_image="#{dirniipath}/#{volaxfolder}/maskedvol.nii.gz"
  
  `standard_space_roi #{newvolax} #{mask_image} -b`
  bet_image="#{dirniipath}/#{volaxfolder}/maskbetvol.nii.gz"
  puts bet_image
   `bet  #{mask_image} #{bet_image} -f 0.15`
end 


#FEAT command line

dirniilist.each do |dn|
  puts  dn
  
nifftifiled= Dir.glob("#{dirniipath}/#{dn}/*.nii")
nifftifile=nifftifiled[0];
puts nifftifile

isvol=nifftifile.scan("ORTOGONAL")


if isvol.empty?
  puts "no ortogonal"
  `cp /Users/catalinabustamante/Documents/codigo/rubyfmri/design_tem.fsf #{dirniipath}/#{dn}/design_tem.fsf`
  else
    puts "ortogonal"
  `cp /Users/catalinabustamante/Documents/codigo/rubyfmri/design_tem_o.fsf #{dirniipath}/#{dn}/design_tem.fsf`
end


path="#{dirniipath}/#{dn}/design_tem.fsf"
puts path
design = File.read(path) 
replace=design.gsub(/set fmri\(([npts)]+)\) 80/,"set fmri(npts) #{nvolumes}")
replace = replace.gsub(/set fmri\(([z_thresh)]+)\) 2.3/, "set fmri(z_thresh) #{zthreshold}")
replace = replace.gsub(/set feat_files\(([1)]+)\) pathf/, "set feat_files(1) \"#{nifftifile}\"")
replace = replace.gsub(/set highres_files\(([1)]+)\) paths/, "set highres_files(1) \"#{bet_image}\"")
File.open(path, "w") {|file| file.puts replace}
`feat #{path}`

featpath=Dir.glob("#{dirniipath}/#{dn}/*.feat")
featpath=featpath[0]
    puts featpath

`/usr/local/fsl/bin/renderhighres #{featpath} standard highres 1 1 15`
 
if dn==dirniilist[0]
  matriz=Dir.glob("#{featpath}/reg/highres2standard.mat")
  `flirt -in #{flair} -ref /usr/local/fsl/data/standard/MNI152_T1_2mm_brain -out #{flair_reg} -init #{matriz} -applyxfm`
end


end

end_time = Time.now
puts "Time elapsed #{(end_time - beginning_time)} seconds"