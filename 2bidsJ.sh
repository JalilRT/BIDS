#!/bin/bash

set -e
#### Modificar la dirección de los archivos dicom
toplvl=/home/kh/Documents/fmri_files/EmocionesAH
dcmdir=/home/kh/Documents/fmri_files/EmocionesAH/Dicoms
dcm2niidir=/usr/bin/

#Crear la carpeta nifti
mkdir -p ${toplvl}/Nifti
niidir=${toplvl}/Nifti

### instalar en terminal el comando jo: sudo apt install jo
###crear el archivo descriptivo de la base de datos (dataset_description.json)
## Al validar puede generar el error Authors should be array, los autores deben estar entre corchetes []
jo -p "Name"="Communicative intention and emotional faces dataset" "BIDSVersion"="1.1.1" "License"="CC-BY 4.0" "Authors"= "Rasgado-Toledo, J." >> ${niidir}/dataset_description.json

#### Organizar las carpetas para los datos, acá se debe agregar cada uno de los sujetos
for subj in 1900; do
	echo "Processing subject $subj"

###Crear la subcarpetas nifti
mkdir -p ${niidir}/sub-${subj}/anat

###Convertir dcm a nii
#Convertir la carpeta dicom, de acuerdo al nombre de la carpeta de salida del T1. El * representa una carpeta con diverso nombre entre ambos directorios
for direcs in Sag_T1_FSPGR_BRAVO*; do
${dcm2niidir}/dcm2niix -o ${niidir}/sub-${subj} -f ${subj}_%f_%p ${dcmdir}/${subj}/*/${direcs}
done

#Cambiar el directorio al de los sujetos
cd ${niidir}/sub-${subj}

###Cambiar los nombres de los archivos
##Renombrar archivos anatómicos
## colocar una descripción que se adapte al archivo
## 1814_Sag_T1_FSPGR_BRAVO_10_Sag_T1_FSPGR_BRAVO
## para el caso, el Sag_T1_FSPGR_BRAVO, describe los nombres de exportación anatómicos de sharon
#se transformará a un nombre con compatibilidad en BIDS: sub-1814_T1w
#Captura el # de anatómicos
anatfiles=$(ls -1 *Sag_T1_FSPGR_BRAVO* | wc -l)
for ((i=1;i<=${anatfiles};i++)); do
Anat=$(ls *Sag_T1_FSPGR_BRAVO*) #This is to refresh the Anat variable, if this is not in the loop, each iteration a new "No such file or directory error", this is because the filename was changed.
tempanat=$(ls -1 $Anat | sed '1q;d') #iteraciones de archivos a modificar
tempanatext="${tempanat##*.}"
tempanatfile="${tempanat%.*}"
mv ${tempanatfile}.${tempanatext} sub-${subj}_T1w.${tempanatext}
echo "${tempanat} changed to sub-${subj}_T1w.${tempanatext}"
done

## organiza los archivos a las carpetas correspondientes
for files in $(ls sub*); do
Orgfile="${files%.*}"
Orgext="${files##*.}"
Modality=$(echo $Orgfile | rev | cut -d '_' -f1 | rev)
if [ $Modality == "T1w" ]; then
	mv ${Orgfile}.${Orgext} anat
fi
done

### Modificación de archivos funcionales
#Crear la subcarpeta funcional
#dependiendo del número de sesiones agregar entre sub y func: {ses-1,ses-2}
mkdir -p ${niidir}/sub-${subj}/func

###Convertir dcm a nii
## modificar el nombre de cada carpeta dependiendo de la descripción puesta en el resonador
## en el caso de haber parado la secuencia en el resonador se crea una carpeta con un nombre similar, eliminarla antes de correr el script
for direcs in fMRI_Jalil_1* fMRI_Jalil_2* fMRI_Jalil_3* fMRI_Jalil_4*; do
${dcm2niidir}/dcm2niix -o ${niidir}/sub-${subj} -f ${subj}_${direcs}_%p_%s ${dcmdir}/${subj}/*/${direcs}
done
# if [[ $direcs == "session1" || $direcs == "session2" ]]; then  ##adaptado en caso de adquirir datos en varias sesiones
for rest in fMRI_RestState*; do
${dcm2niidir}/dcm2niix -o ${niidir}/sub-${subj} -f ${subj}_${direcs}_%p_%s ${dcmdir}/${subj}/*/${rest}
# done
# else  #en caso de adquirir en varias sesiones
## ${dcm2niidir}/dcm2niix -o ${niidir}/sub-${subj} -f ${subj}_${direcs}_%p ${dcmdir}/${subj}/${direcs}
#fi
done

### Renombrar los archivos
#Cambiar el directorio a la del sujeto
cd ${niidir}/sub-${subj}

## modificar el resting
#nombre de ejemplo: fMRI_Jalil_4___fMRI_RestState_3
#nombre formato BIDS: sub-1814_task-rest_bold
for corrun in $(ls *fMRI_RestState*); do
corrunfile="${corrun%.*}"
corrunfileext="${corrun##*.}"
mv ${corrunfile}.${corrunfileext} sub-${subj}_task-rest_bold.${corrunfileext}
echo "${corrun} changed to sub-${subj}_task-rest_bold.${corrunfileext}"
done

##Renombrar los	archivos funcionales
#Checkerboard task
#Ejemplo de nombre de archivo: 1814_fMRI_Jalil_1___fMRI_Jalil_1_6
# eah(emociones_acto_habla)=nombre de la tarea
#nombre de archivo formato BIDS: sub-1814_task-eah_bold
#modificar el número de archivos comprobables a cambiar
checkerfiles=$(ls -1 *fMRI_Jalil* | wc -l)
for ((i=1;i<=${checkerfiles};i++)); do
Checker=$(ls *fMRI_Jalil*) #This is to refresh the Checker variable, same as the Anat case
tempcheck=$(ls -1 $Checker | sed '1q;d') #Capture new file to change
tempcheckext="${tempcheck##*.}"
tempcheckfile="${tempcheck%.*}"
run=$(echo $tempcheck | cut -d '_' -f4) #f4 es el cuarto campo definido por un _ para capturar la corrida del nombre de archivo
mv ${tempcheckfile}.${tempcheckext} sub-${subj}_task-eah_run-0${run}_bold.${tempcheckext}
echo "${tempcheckfile}.${tempcheckext} changed to sub-${subj}_task-eah_run-${run}_bold.${tempcheckext}"
done

###Organize files into folders
for files in $(ls sub*); do
Orgfile="${files%.*}"
Orgext="${files##*.}"
Modality=$(echo $Orgfile | rev | cut -d '_' -f1 | rev)
#Sessionnum=$(echo $Orgfile | cut -d '_' -f2)
#Difflast=$(echo "${Sessionnum: -1}")
# if [[ $Modality == "bold" && $Difflast == 2 ]]; then
mv ${Orgfile}.${Orgext} func
#else
#if [[ $Modality == "bold" && $Difflast == 1 ]]; then
#	mv ${Orgfile}.${Orgext} func
#fi
#fi
done

## renombrar los archivos .gz a .nii.gz
cd ${niidir}/sub-${subj}
for direcc in anat func; do
cd ${niidir}/sub-${subj}/${direcc}
for files in $(ls *.gz); do
Orgfile="${files%.*}"
Orgext="${files##*.}"
mv ${Orgfile}.${Orgext} ${Orgfile}.nii.${Orgext}
done
done

##crear tsv con datos de los estímulos y agregarlos a las carpetas correspondientes
# checar si contienen el elemento "TaskName" dentro del json, y si no, agregarlo
###Check func json for required fields
#Required fields for func: 'RepetitionTime','VolumeTiming' or 'SliceTiming', and 'TaskName'
#capture all jsons to test
cd ${niidir}/sub-${subj}/func #Go into the func folder
for funcjson in $(ls *.json); do

##Repeition Time exist?
#Instalar paquete jq: sudo apt install jq
repeatexist=$(cat ${funcjson} | jq '.RepetitionTime')
if [[ ${repeatexist} == "null" ]]; then
	echo "${funcjson} doesn't have RepetitionTime defined"
else
echo "${funcjson} has RepetitionTime defined"
fi

#VolumeTiming or SliceTiming exist?
#Constraint SliceTiming can't be great than TR
volexist=$(cat ${funcjson} | jq '.VolumeTiming')
sliceexist=$(cat ${funcjson} | jq '.SliceTiming')
if [[ ${volexist} == "null" && ${sliceexist} == "null" ]]; then
echo "${funcjson} doesn't have VolumeTiming or SliceTiming defined"
else
if [[ ${volexist} == "null" ]]; then
echo "${funcjson} has SliceTiming defined"
#Check SliceTiming is less than TR
sliceTR=$(cat ${funcjson} | jq '.SliceTiming[] | select(.>="$repeatexist")')
if [ -z ${sliceTR} ]; then
echo "All SliceTiming is less than TR" #The slice timing was corrected in the newer dcm2niix version called through command line
else
echo "SliceTiming error"
fi
else
echo "${funcjson} has VolumeTiming defined"
fi
fi

#Does TaskName exist?
taskexist=$(cat ${funcjson} | jq '.TaskName')
if [ "$taskexist" == "null" ]; then
jsonname="${funcjson%.*}"
taskfield=$(echo $jsonname | cut -d '_' -f2 | cut -d '-' -f2)
jq '. |= . + {"TaskName":"'${taskfield}'"}' ${funcjson} > tasknameadd.json
rm ${funcjson}
mv tasknameadd.json ${funcjson}
echo "TaskName was added to ${jsonname} and matches the tasklabel in the filename"
else
Taskquotevalue=$(jq '.TaskName' ${funcjson})
Taskvalue=$(echo $Taskquotevalue | cut -d '"' -f2)
jsonname="${funcjson%.*}"
taskfield=$(echo $jsonname | cut -d '_' -f2 | cut -d '-' -f2)
if [ $Taskvalue == $taskfield ]; then
echo "TaskName is present and matches the tasklabel in the filename"
else
echo "TaskName and tasklabel do not match"
fi
fi

done


done
