#!/usr/bin/env ruby
# the Dicom folder has to have the number of volumes in the name ex: Hand_80
# Modules required:
require 'rubygems'
require 'dcm2nii-ruby'
require 'fsl-ruby'
require 'narray'
require 'nifti'
require 'optparse'
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
trvalue=3.0000000000


# CAMBIAR EL NOMBRE DE LA CARPETA QUE CONTIENE LOS DICOMS
dirname= Dir.entries(inidicom).select {|entry| File.directory? File.join(inidicom,entry) and !(entry =='.' || entry == '..') }

completepath="#{inidicom}/#{dirname[0]}"
newname="#{inidicom}/0DICOM"
niifile="#{inidicom}/NIFTI"

FileUtils.mkdir niifile

FileUtils.mv completepath, newname

#CONVERT DICOM TO NIFTI
#SE CORRE EL COMANDO DE MCVERTER

`mcverter -f fsl -x -d -n -o #{niifile} #{inidicom}`

dirnewname= Dir.entries(inidicom).select {|entry| File.directory? File.join(inidicom,entry) and !(entry =='.' || entry == '..') }

dirniiname=dirnewname[1]

dirniipath="#{inidicom}/#{dirniiname}"

puts dirniipath
dirniilist=Dir.entries(dirniipath).select {|entry| File.directory? File.join(dirniipath,entry) and !(entry =='.' || entry == '..') }

volaxfolder=1
flair=1
dirniilist.each do |name|
  
  isvol=name.scan("VOL_AX")
  
  if isvol.empty?
    else
      puts "el volumetrico"
      volaxfolder=name
  end
  
  isflair=name.scan("FLAIR")
  
  if isflair.empty?
  else
    flair=name
  end
end
puts "volaxial"
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

isvol=nifftifile.scan("ORTO")


if isvol.empty?
  puts "no ortogonal"
  `cp /Users/investigacioniatm/Documents/codigo/rubyfmri/design_tem_1_5_120.fsf #{dirniipath}/#{dn}/design_tem_1_5_120.fsf`
  else
    puts "ortogonal"
  `cp /Users/investigacioniatm/Documents/codigo/rubyfmri/design_tem_1_5_120_o.fsf #{dirniipath}/#{dn}/design_tem_1_5_120.fsf`
end


path="#{dirniipath}/#{dn}/design_tem_1_5_120.fsf"
puts path
design = File.read(path) 
replace = design.gsub(/set fmri\(([npts)]+)\) 120/,"set fmri(npts) #{nvolumes}")
replace = replace.gsub(/set fmri\(([z_thresh)]+)\) 2.3/, "set fmri(z_thresh) #{zthreshold}")
replace = replace.gsub(/set feat_files\(([1)]+)\) pathf/, "set feat_files(1) \"#{nifftifile}\"")
replace = replace.gsub(/set highres_files\(([1)]+)\) paths/, "set highres_files(1) \"#{bet_image}\"")
File.open(path, "w") {|file| file.puts replace}
`feat #{path}`

featpath=Dir.glob("#{dirniipath}/#{dn}/*.feat")
featpath=featpath[0]
    puts featpath

`/usr/local/fsl/bin/renderhighres #{featpath} standard highres 1 1 15`

matriz= "#{featpath}/hr/background_reg.mat" 

`flirt -in #{featpath}/hr/background.nii.gz -ref #{bet_image} -out #{featpath}/hr/background_reg.nii.gz -omat #{matriz} -bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear`

thpath=Dir.glob("#{featpath}/hr/thresh_zstat*.nii.gz")


thpath.each do |th|
  puts th
  threg=th.gsub('.nii.gz', '_reg.nii.gz')
  puts threg
  puts flairdir
  puts matriz
  `flirt -in #{th} -ref #{bet_image} -init #{matriz} -out #{threg} -applyxfm`
end


end


end_time = Time.now
puts "Time elapsed #{(end_time - beginning_time)} seconds"