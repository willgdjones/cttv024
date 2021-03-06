DEST_DIR=./databases

#default: create_dir GRASP Phewas_Catalog GWAS_DB Fantom5 DHS Regulome Phenotypes

download: create_dir d_GRASP d_Phewas_Catalog d_GWAS_DB d_Fantom5 d_DHS d_Regulome d_1000Genomes
process_databases: GRASP Phewas_Catalog GWAS_DB Fantom5 DHS Regulome
process_1000G: 1000Genomes

clean_raw:
	rm -rf ${DEST_DIR}/raw/*

clean_all:
	rm -rf ${DEST_DIR}/*

create_dir:
	mkdir -p ${DEST_DIR}
	mkdir -p ${DEST_DIR}/raw

d_GRASP:
	wget -nc https://s3.amazonaws.com/NHLBI_Public/GRASP/GraspFullDataset2.zip -qO ${DEST_DIR}/raw/GRASP.zip

GRASP:
	unzip -c ${DEST_DIR}/raw/GRASP.zip | python scripts/preprocessing/column.py 12 > ${DEST_DIR}/GRASP.txt


d_Phewas_Catalog:
	wget -nc http://phewas.mc.vanderbilt.edu/phewas-catalog.csv > ${DEST_DIR}/raw/Phewas_Catalog.csv

Phewas_Catalog: 
	python scripts/preprocessing/csvToTsv.py ${DEST_DIR}/raw/Phewas_Catalog.csv  > ${DEST_DIR}/Phewas_Catalog.txt



d_GWAS_DB:
	wget -nc ftp://jjwanglab.org/GWASdb/old_release/GWASdb_snp_v4.zip -O ${DEST_DIR}/raw/GWAS_DB.zip
GWAS_DB:
	unzip -c ${DEST_DIR}/raw/GWAS_DB.zip > ${DEST_DIR}/GWAS_DB.txt

GWAS_Catalog:
	wget https://www.ebi.ac.uk/gwas/api/search/downloads/alternative -O ${DEST_DIR}/raw/GWAS_Catalog.txt

d_Fantom5:
	wget -nc http://enhancer.binf.ku.dk/presets/enhancer_tss_associations.bed -O ${DEST_DIR}/raw/Fantom5.txt

Fantom5:
	cat ${DEST_DIR}/raw/Fantom5.txt | cut -f4 | tr ';' '\t' | cut -f1,3,5 | grep 'FDR:' | sed -e 's/FDR://' -e 's/^chr//' -e 's/-/\t/' -e 's/:/\t/' > ${DEST_DIR}/Fantom5.bed
	cat ${DEST_DIR}/Fantom5.bed | python scripts/preprocessing/STOPGAP_FDR.py > ${DEST_DIR}/Fantom5.fdrs

d_DHS:
	wget -nc ftp://ftp.ebi.ac.uk/pub/databases/ensembl/encode/integration_data_jan2011/byDataType/openchrom/jan2011/dhs_gene_connectivity/genomewideCorrs_above0.7_promoterPlusMinus500kb_withGeneNames_32celltypeCategories.bed8.gz -qO ${DEST_DIR}/raw/DHS.txt.gz 

DHS:
	gzip -dc ${DEST_DIR}/raw/DHS.txt.gz | awk 'BEGIN {OFS="\t"} {print $$5,$$6,$$7,$$4,$$8}' | sed -e 's/^chr//' > ${DEST_DIR}/DHS.txt
	cat ${DEST_DIR}/DHS.txt | python scripts/preprocessing/STOPGAP_FDR.py > ${DEST_DIR}/DHS.fdrs

d_Regulome:
	wget -nc http://regulomedb.org/downloads/RegulomeDB.dbSNP132.Category1.txt.gz -qO ${DEST_DIR}/raw/regulome1.csv.gz
	wget -nc http://regulomedb.org/downloads/RegulomeDB.dbSNP132.Category2.txt.gz -qO ${DEST_DIR}/raw/regulome2.csv.gz
	wget -nc http://regulomedb.org/downloads/RegulomeDB.dbSNP132.Category3.txt.gz -qO ${DEST_DIR}/raw/regulome3.csv.gz

Regulome:
	gzip -dc ${DEST_DIR}/raw/regulome1.csv.gz > ${DEST_DIR}/regulome1.csv
	gzip -dc ${DEST_DIR}/raw/regulome2.csv.gz > ${DEST_DIR}/regulome2.csv
	gzip -dc ${DEST_DIR}/raw/regulome3.csv.gz > ${DEST_DIR}/regulome3.csv
	cat ${DEST_DIR}/regulome1.csv ${DEST_DIR}/regulome2.csv ${DEST_DIR}/regulome3.csv > ${DEST_DIR}/regulome.csv
	rm ${DEST_DIR}/regulome1.csv ${DEST_DIR}/regulome2.csv ${DEST_DIR}/regulome3.csv
	awk 'BEGIN {FS="\t"} { print $$1,$$2,$$2 + 1,$$4 }' ${DEST_DIR}/regulome.csv | sed -e 's/^chr//' > ${DEST_DIR}/Regulome.bed
	python scripts/preprocessing/regulome_tidy.py ${DEST_DIR}

d_1000Genomes:
	mkdir -p ./databases/raw/1000Genomes
	for url in `cat ./scripts/preprocessing/links.txt`; do wget -nc $${url} -P ./databases/raw/1000Genomes/; done
1000Genomes: 
	for i in `seq 22; echo X; echo Y`; do \
		echo "processing chr $${i}"; \
		cat ./databases/raw/1000Genomes/ALL.chr$${i}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz \
		| bgzip -dc | \
		vcfkeepsamples - `cat ./scripts/preprocessing/CEPH_samples.txt` \
		| bcftools convert -Ob \
		> ./databases/1000Genomes/CEPH/CEPH.chr$${i}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.bcf.gz; \
		echo "indexing CEPH chr$$i"; \
		tabix -f ./databases/1000Genomes/CEPH/CEPH.chr$${i}.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.bcf.gz
	done;

