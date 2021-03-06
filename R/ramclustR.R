#' ramclustR
#'
#' Main clustering function 
#'
#' This is the Details section
#'
#' @param filename character Filename of the nmrML to check
#' @param ms MS1 intensities =MSdata, 
#' @param idmsms =ms,  
#' @param idMSMStag character e.g. "02.cdf"
#' @param featdelim character e.g. ="_"
#' @param timepos numeric 2
#' @param st numeric no clue e.g. = 5, 
#' @param sr numeric also no clue yet = 5, 
#' @param maxt numeric again no clue =20, 
#' @param deepSplit boolean e.g. =FALSE, 
#' @param blocksize integer number of features (scans?) processed in one block  =1000,
#' @param mult numeric =10
#'
#' @return A vector with the numeric values of the processed data
#' @author Corey Broeckling
#' @export

ramclustR<- function(  xcmsObj=NULL,
                       ms=NULL, 
                       idmsms=NULL,
                       taglocation="filepaths",
                       MStag=NULL,
                       idMSMStag=NULL, 
                       featdelim="_", 
                       mzpos=1, 
                       timepos=2, 
                       st=NULL, 
                       sr=NULL, 
                       maxt=NULL, 
                       deepSplit=FALSE, 
                       blocksize=2000,
                       mult=5,
                       hmax=NULL,
                       sampNameCol=NULL,
                       collapse=TRUE,
                       mspout=TRUE, 
                       mslev=1,
		       ExpDes=NULL,
		       normalize="TIC",
		       minModuleSize=2,
                       linkage="average") {
    
  if(is.null(xcmsObj) & is.null(ms))  {
	  stop("you must select either 
          1: an MS dataset with features as columns 
             (__)one column may contain sample names, defined by sampNameCol) 
          2: an xcmsObj. If you choose an xcms object, set taglocation: 'filepaths' by default
            and both MStag and idMSMStag")}

  if(!is.null(xcmsObj) & mslev==2 & any(is.null(MStag), is.null(idMSMStag), is.null(taglocation)))
  {stop("you must specify the the MStag, idMSMStag, and the taglocations")}
  
  if(is.null(ExpDes) & mspout==TRUE){
  cat("please enter experiment description (see popup window), or set 'mspout=FALSE'")
  ExpDes<-defineExperiment()
  }
	
  if(is.null(ExpDes) & mspout==FALSE){
  warning("using undefined instrumental settings")
  ExpDes<-paramsets$undefined
  }


  if( normalize!="none"  & normalize!="TIC" & normalize!="quantile") {
	stop("please selected either 'none', 'TIC', or 'quantile' for the normalize setting")}

  a<-Sys.time()   
  
  if(is.null(hmax)) {hmax<-0.3}
  ##in using non-xcms data as input
  ##remove MSdata sets and save data matrix alone
  if(!is.null(ms)){
    if(is.null(st)) stop("please specify st: 
      a recommended starting point is half the value of 
      your average chromatographic peak width at half max (seconds)")
    if(is.null(sr)) sr<-0.15
    if(is.null(maxt)) maxt<-60
    MSdata<-read.csv(ms, header=TRUE, check.names=FALSE)
	if(!is.null(idmsms)){
    MSMSdata<-read.csv(idmsms, header=TRUE, check.names=FALSE)}
	if(is.null(idmsms)) { MSMSdata<-MSdata}
    if(is.null(sampNameCol)) {featcol<-1:ncol(MSdata)} else {
      featcol<-setdiff(1:(ncol(MSdata)), sampNameCol)}
    if(is.null(sampNameCol)) {featcol<-1:ncol(MSdata)} else {
      featcol<-setdiff(1:(ncol(MSdata)), sampNameCol)}
    sampnames<-MSdata[,sampNameCol]
    data1<-as.matrix(MSdata[,featcol])
	dimnames(data1)[[1]]<-MSdata[,sampNameCol]
	dimnames(data1)[[2]]<-names(MSdata[,featcol])
    data2<-as.matrix(MSMSdata[,featcol])
	dimnames(data2)[[1]]<-MSMSdata[,sampNameCol]
	dimnames(data2)[[2]]<-names(MSMSdata[,featcol])
    if(!all(dimnames(data1)[[2]]==dimnames(data2)[[2]])) 
    {stop("the feature names of your MS and idMSMS data are not identical")}
    
    if(!all(dimnames(data1)[[1]]==dimnames(data2)[[1]])) 
    {stop("the order and names of your MS and idMSMS data sample names are not identical")}
    
    rtmz<-matrix(
      unlist(
        strsplit(dimnames(data1)[[2]], featdelim)
      ), 
      byrow=TRUE, ncol=2)
    times<-as.numeric(rtmz[,timepos])
    mzs<-as.numeric(rtmz[,which(c(1:2)!=timepos)])
    rm(rtmz)     
  }
  
  ##if xcms object is selected instead of an R dataframe/matrix
  if(!is.null(xcmsObj)){
    if(!class(xcmsObj)=="xcmsSet")
    {stop("xcmsObj must reference an object generated by XCMS, of class 'xcmsSet'")}
    
    if(is.null(st)) st<-round(median(xcmsObj@peaks[,"rtmax"]-xcmsObj@peaks[,"rtmin"])/2, digits=2)
    if(is.null(sr)) sr<-st/5
    if(is.null(maxt)) maxt<-st*20
    
    sampnames<-row.names(xcmsObj@phenoData)
    data12<-groupval(xcmsObj, value="into")
    if(taglocation=="filepaths" & !is.null(MStag)) 
    { msfiles<-grep(MStag, xcmsObj@filepaths, ignore.case=TRUE)
      msmsfiles<-grep(idMSMStag, xcmsObj@filepaths, ignore.case=TRUE)
      if(length(intersect(msfiles, msmsfiles)>0)) 
      {stop("your MS and idMSMStag values do not generate unique file lists")}
      if(length(msfiles)!=length(msmsfiles)) 
      {stop("the number of MS files must equal the number of MSMS files")}
      data1<-t(data12[,msfiles])
      row.names(data1)<-sampnames[msfiles]
      data2<-t(data12[,msmsfiles])
      row.names(data2)<-sampnames[msmsfiles]  ##this may need to be changed to dimnames..
       times<-round(xcmsObj@groups[,"rtmed"], digits=3)
      mzs<-round(xcmsObj@groups[,"mzmed"], digits=4)
    } else {
      data1<-t(data12)
      data2<-t(data12)
      times<-round(xcmsObj@groups[,"rtmed"], digits=3)
      mzs<-round(xcmsObj@groups[,"mzmed"], digits=4)      
      }
  }


##replace na and NaN with min dataset value
    data1[which(is.na(data1))]<-min(data1, na.rm=TRUE)
    data2[which(is.na(data2))]<-min(data2, na.rm=TRUE)
    data1[which(is.nan(data1))]<-min(data1, na.rm=TRUE)
    data2[which(is.nan(data2))]<-min(data2, na.rm=TRUE)
    
##Optional normalization of data, either Total ion signal or quantile
  
  if(normalize=="TIC") {
	data1<-(data1/rowSums(data1))*mean(rowSums(data1), na.rm=TRUE)
	data2<-(data2/rowSums(data2))*mean(rowSums(data2), na.rm=TRUE)
	}
  if(normalize=="quantile") {
	data1<-t(preprocessCore::normalize.quantiles(t(data1)))
	data2<-t(preprocessCore::normalize.quantiles(t(data2)))	
	}


  ##retention times and mzs vectors
  
  ##sort rt vector and data by retention time
  data1<-data1[,order(times)]
  data2<-data2[,order(times)]
  mzs<-mzs[order(times)]
  times<-times[order(times)]
  
  ##extract names (would like to be pulling from XCMS set instead...)
  featnames<-paste(mzs, "_", times, sep="")
  dimnames(data1)[[2]]<-featnames
  dimnames(data2)[[2]]<-featnames
  
  
  ##establish some constants for downstream processing
  n<-ncol(data1)
  vlength<-(n*(n-1))/2
  nblocks<-floor(n/blocksize)
  
  ##create three empty matrices, one each for the correlation matrix, the rt matrix, and the product matrix
  #ffcor<-ff(vmode="double", dim=c(n, n), init=0)
  #gc()
  #ffrt<-ff(vmode="double", dim=c(n, n), init=0)
  #gc()
  ffmat<-ff(vmode="double", dim=c(n, n), initdata = 0) ##reset to 1 if necessary
  gc()
  #Sys.sleep((n^2)/10000000)
  #gc()
  
  ##make list of all row and column blocks to evaluate
  eval1<-expand.grid(0:nblocks, 0:nblocks)
  names(eval1)<-c("j", "k") #j for cols, k for rows
  eval1<-eval1[which(eval1[,"j"]<=eval1[,"k"]),] #upper triangle only
  bl<-nrow(eval1)
  cat('\n', paste("calculating ramclustR similarity: nblocks = ", bl))
  cat('\n', "finished:")
  
  RCsim<-function(bl)  {
    cat(bl,' ')
    j<-eval1[bl,"j"]  #columns
    k<-eval1[bl,"k"]  #rows
    startc<-min((1+(j*blocksize)), n)
    if ((j+1)*blocksize > n) {
      stopc<-n} else {
        stopc<-(j+1)*blocksize}
    startr<-min((1+(k*blocksize)), n)
    if ((k+1)*blocksize > n) {
      stopr<-n} else {
        stopr<-(k+1)*blocksize}
    if(startc<=startr) { 
      mint<-min(outer(times[startr:stopr], times[startc:stopc], FUN="-"))
      if(mint<=maxt) {
        temp1<-round(exp(-(( (abs(outer(times[startr:stopr], times[startc:stopc], FUN="-"))))^2)/(2*(st^2))), digits=20 )
        #stopifnot(max(temp)!=0)
        #ffrt[startr:stopr, startc:stopc]<- temp
        temp2<-round (exp(-((1-(pmax(  cor(data1[,startr:stopr], data1[,startc:stopc]),
                                      cor(data1[,startr:stopr], data2[,startc:stopc]),
                                      cor(data2[,startr:stopr], data2[,startc:stopc])  )))^2)/(2*(sr^2))), digits=20 )		
        #ffcor[startr:stopr, startc:stopc]<-temp
        temp<- 1-(temp1*temp2)
        ffmat[startr:stopr, startc:stopc]<-temp
        rm(temp1); rm(temp2); rm(temp)
        gc()} 
      if(mint>maxt) {ffmat[startr:stopr, startc:stopc]<- 1}
    }
    gc()}
 # ffmat[995:1002,995:1002]
  
  ##Call the similarity scoring function
  system.time(sapply(1:bl, RCsim))
  #RCsim(bl=1:bl)
  
  b<-Sys.time()
  
  cat('\n','\n' )
  cat(paste("RAMClust feature similarity matrix calculated and stored:", 
            round(difftime(b, a, units="mins"), digits=1), "minutes"))
  
  #cleanup
  #delete.ff(ffrt)
  #rm(ffrt)
  #delete.ff(ffcor)
  #rm(ffcor)
  gc() 
  
  
  ##extract lower diagonal of ffmat as vector
  blocksize<-mult*round(blocksize^2/n)
  nblocks<-floor(n/blocksize)
  remaind<-n-(nblocks*blocksize)
  
  ##create vector for storing dissimilarities
  RC<-vector(mode="integer", length=vlength)
  
  for(k in 0:(nblocks)){
    startc<-1+(k*blocksize)
    if ((k+1)*blocksize > n) {
      stopc<-n} else {
        stopc<-(k+1)*blocksize}
    temp<-ffmat[startc:nrow(ffmat),startc:stopc]
    temp<-temp[which(row(temp)-col(temp)>0)]
    if(exists("startv")==FALSE) startv<-1
    stopv<-startv+length(temp)-1
    RC[startv:stopv]<-temp
    gc()
    startv<-stopv+1
    rm(temp)
    gc()
  }    
  rm(startv)
  gc()
  
  ##convert vector to distance formatted object
  RC<-structure(RC, Size=(n), Diag=FALSE, Upper=FALSE, method="RAMClustR", Labels=featnames, class="dist")
  gc()
  
  c<-Sys.time()    
  cat('\n', '\n')
  cat(paste("RAMClust distances converted to distance object:", 
            round(difftime(c, b, units="mins"), digits=1), "minutes"))
  
  ##cleanup
  delete.ff(ffmat)
  rm(ffmat)
  gc()
  
  
  ##cluster using fastcluster package,
  system.time(RC<-hclust(RC, method=linkage))
  gc()
  d<-Sys.time()    
  cat('\n', '\n')    
  cat(paste("fastcluster based clustering complete:", 
            round(difftime(d, c, units="mins"), digits=1), "minutes"))
  if(minModuleSize==1) {
	clus<-cutreeDynamicTree(RC, maxTreeHeight=hmax, deepSplit=deepSplit, minModuleSize=2)
	sing<-which(clus==0)
	clus[sing]<-max(clus)+1:length(sing)
	}
  if(minModuleSize>1) {
 	clus<-cutreeDynamicTree(RC, maxTreeHeight=hmax, deepSplit=deepSplit, minModuleSize=minModuleSize)
	}
  gc()
 
  
  RC$featclus<-clus
  RC$frt<-times
  RC$fmz<-mzs
  RC$nfeat<-as.vector(table(RC$featclus)[2:max(RC$featclus)])
  RC$nsing<-length(which(RC$featclus==0))
  
  e<-Sys.time() 
  cat('\n', '\n')
  cat(paste("dynamicTreeCut based pruning complete:", 
            round(difftime(e, d, units="mins"), digits=1), "minutes"))
  
  f<-Sys.time()
  cat('\n', '\n')
  cat(paste("RAMClust has condensed", n, "features into",  max(clus), "spectra in", round(difftime(f, a, units="mins"), digits=1), "minutes", '\n'))
  
  if(collapse=="TRUE") {
    cat('\n', '\n', "... collapsing features into spectra")
    wts<-colSums(data1[])
    RC$SpecAbund<-matrix(nrow=nrow(data1), ncol=max(clus))
    for (ro in 1:nrow(RC$SpecAbund)) { 
      for (co in 1:ncol(RC$SpecAbund)) {
        RC$SpecAbund[ro,co]<- weighted.mean(data1[ro,which(RC$featclus==co)], wts[which(RC$featclus==co)])
      }
    }
    g<-Sys.time()
    cat('\n', '\n')
    cat(paste("RAMClustR has collapsed feature quantities
             into spectral quantities:", round(difftime(g, f, units="mins"), digits=1), "minutes", '\n'))
  }
  
  RC$ExpDes<-ExpDes
  RC$MSdata<-data1
  RC$MSMSdata<-data2
  rm(data1)
  rm(data2)
  
  gc()
  
 if(mspout==TRUE){ 
    cat(paste("writing msp formatted spectra...", '\n'))
    
    libName<-paste(ExpDes$design["Experiment", "ExpVals"], ".mspLib", sep="")
    file.create(file=libName)
    for (m in 1:as.numeric(mslev)){
      for (j in 1:max(RC$featclus)) {
        sl<-which(RC$featclus==j)
        wm<-vector(length=length(sl))
        if(m==1) {wts<-rowSums(RC$MSdata[,sl])
                  for (k in 1:length(sl)) {     
                    wm[k]<-weighted.mean(RC$MSdata[,sl[k]], wts)
                  }}
        if(m==2) {wts<-rowSums(RC$MSMSdata[,sl])
                  for (k in 1:length(sl)) {    
                    wm[k]<-weighted.mean(RC$MSMSdata[,sl[k]], wts)
                  }}
        mz<-RC$fmz[sl][order(wm, decreasing=TRUE)]
        rt<-RC$frt[sl][order(wm, decreasing=TRUE)]
        wm<-wm[order(wm, decreasing=TRUE)]
        mrt<-mean(rt)
        npeaks<-length(mz)
        for (l in 1:length(mz)) {
          ion<- paste(round(mz[l], digits=4), round(wm[l]))
          if(l==1) {specdat<-ion} 
          if(l>1)  {specdat<-c(specdat, " ", ion)}
        }
        cat(
          paste("Name: C", j, sep=""), '\n',
          paste("SYNON: $:00in-source", sep=""), '\n',
          paste("SYNON: $:04", sep=""), '\n', 
          paste("SYNON: $:05", if(m==1) {ExpDes$instrument["CE1", "InstVals"]} else {ExpDes$instrument["CE2", "InstVals"]}, sep=""), '\n',
          paste("SYNON: $:06", ExpDes$instrument["mstype", "InstVals"], sep=""), '\n',           #mstype
          paste("SYNON: $:07", ExpDes$instrument["msinst", "InstVals"], sep=""), '\n',           #msinst
          paste("SYNON: $:09", ExpDes$instrument["chrominst", "InstVals"], sep=""), '\n',        #chrominst
          paste("SYNON: $:10", ExpDes$instrument["ionization", "InstVals"], sep=""),  '\n',      #ionization method
          paste("SYNON: $:11", ExpDes$instrument["msmode", "InstVals"], sep=""), '\n',           #msmode
          paste("SYNON: $:12", ExpDes$instrument["colgas", "InstVals"], sep=""), '\n',           #collision gas
          paste("SYNON: $:14", ExpDes$instrument["msscanrange", "InstVals"], sep=""), '\n',      #ms scanrange
          paste("SYNON: $:16", ExpDes$instrument["conevolt", "InstVals"], sep=""), '\n',         #conevoltage
          paste("Comment: Rt=", round(mrt, digits=2), 
                "  Contributor=", ExpDes$design["Contributor", "ExpVals"], 
                "  Study=", ExpDes$design["Experiment", "ExpVals"], 
                sep=""), '\n',
          paste("Num Peaks:", npeaks), '\n',
          paste(specdat), '\n', '\n', sep="", file=libName, append= TRUE)
      }
    }
    cat(paste('\n', "msp file complete", '\n')) 
  }  
  return(RC)
}
