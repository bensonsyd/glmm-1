## summary does all the calculations
summary.glmm <- function(object,...){
    mod.mcml<-object
    stopifnot(inherits(mod.mcml, "glmm"))

	trust.converged<-mod.mcml$trust.converged
	fixedcall<-mod.mcml$fixedcall
	randcall<-mod.mcml$randcall
	call<-mod.mcml$call
	x<-mod.mcml$x
	y<-mod.mcml$y
	z<-mod.mcml$z
	
	#the coefficients matrix for fixed effects
	#truncating beta significance based on mcse
	mcerror<- mcse(mod.mcml)
	split<- strsplit(as.character(mcerror),split="")
	d<-rep(0,length(split))
	for(i in 1:length(split)){
	  j<-1
	    while(split[[i]][j] == "0" | split[[i]][j] == "."){
	      d[i] <- d[i] +1
	      j<-j+1
	    }
	}
	d <- d-1
	
	beta<-mod.mcml$beta
	nbeta<-length(beta)
	hessian<-mod.mcml$loglike.hessian
	if(det(hessian)==0) {
            warning(paste("estimated Fisher information matrix not positive",
               "definite, making all standard errors infinite"))
            all.ses <- rep(Inf, nrow(hessian))
    }else{	
		varcov <-vcov.glmm(mod.mcml)
		all.ses<-sqrt(diag(varcov))
	}
	
	#fixed effects table
	beta.se<-all.ses[1:nbeta]
	zval<-beta/beta.se
	for(i in 1:length(beta)){
	  beta[i] <- round(beta[i], digits = d[i])
	  beta.se[i] <- round(beta.se[i], digits = d[i])
	}
	#beta <- round(beta, digits = d[1])
	#beta.se <- round(beta.se, digits = d[1])
	coefmat<-cbind(beta,beta.se,zval,2*pnorm(abs(zval),lower.tail=F))
	colnames(coefmat)<-c("Estimate","Std. Error", "z value", "Pr(>|z|)")
	rownames(coefmat)<-colnames(mod.mcml$x)
	coefficients<-coefmat[,1]
	
	#variance components table
	nu<-mod.mcml$nu
	nu.se<-all.ses[-(1:nbeta)]
	nuzval<-nu/nu.se
	for(i in 1:length(nu)){
	  nu[i] <- round(nu[i], digits = d[length(beta)+i])
	  nu.se[i] <- round(nu.se[i], digits = d[length(beta)+i])
	}
	#nu <- round(nu, digits = d[2])
	#nu.se <- round(nu.se, digits = d[2])
	nucoefmat<-cbind(nu,nu.se,nuzval,pnorm(abs(nuzval),lower.tail=F))
	colnames(nucoefmat)<-c("Estimate","Std. Error", "z value", "Pr(>|z|)/2")
	rownames(nucoefmat)<-mod.mcml$varcomps.names
	link<-mod.mcml$family.glmm$link


	return(structure(list(x=x,y=y, z=z, coefmat=coefmat, fixedcall = fixedcall, randcall = randcall, coefficients = coefficients, family.mcml = mod.mcml$family.mcml, call = call, nucoefmat = nucoefmat, link = link, trust.converged = trust.converged), class="summary.glmm"))
}


se <- function(object){
    mod.mcml<-object
    stopifnot(inherits(mod.mcml, "glmm"))
	hessian<-mod.mcml$loglike.hessian
	if(det(hessian)==0) {
            warning(paste("estimated Fisher information matrix not positive",
               "definite, making all standard errors infinite"))
            all.ses <- rep(Inf, nrow(hessian))
    }else{	
		varcov <-vcov.glmm(mod.mcml)
		all.ses<-sqrt(diag(varcov))
	}
	
	names(all.ses) <- c(colnames(mod.mcml$x), object$varcomps.names)
	all.ses
}

## print.summary actually displays them
print.summary.glmm <-
    function (x, digits = max(3, getOption("digits") - 3),
        signif.stars = getOption("show.signif.stars"), ...)
{
    summ<-x	
    stopifnot(inherits(summ, "summary.glmm"))

	if(summ$trust.converged==FALSE)  cat("\nWARNING: the optimizer trust has not converged to the MCMLE. The following estimates are not maximum likelihood estimates, but they can be used in the argument par.init when rerunning glmm. \n\n",sep="")

    cat("\nCall:\n", paste(deparse(summ$call), sep = "\n", collapse = "\n"), "\n\n", sep = "")

 cat("\nLink is: ", paste(deparse(summ$link)),"\n\n",sep="")
   
cat("Fixed Effects:")
   cat("\n")

	printCoefmat(summ$coefmat, digits = digits,
        signif.stars = signif.stars, na.print = "NA", ...)
   cat("\n")

   cat("\n")
cat("Variance Components for Random Effects (P-values are one-tailed):")
   cat("\n")

	printCoefmat(summ$nucoefmat, digits = digits,
        signif.stars = signif.stars, na.print = "NA", ...)
   cat("\n")



}


#just display the coefficients (the fixed effects estimates)
coef.glmm <-
function(object,...){
	mod<-object
   	stopifnot(inherits(mod, "glmm"))
	coefficients<-mod$beta
	names(coefficients)<-colnames(mod$x)
	coefficients
}

#variance covariance matrix
vcov.glmm <-
function(object,...){
	mod<-object
   	stopifnot(inherits(mod, "glmm"))
	vcov <- qr.solve(-mod$loglike.hessian)


	#get names for vcov matrix
	rownames(vcov)<-colnames(vcov)<-rep(c("blah"),nrow(vcov))
	nbeta<-length(mod$beta)
	rownames(vcov)[1:nbeta] <- colnames(vcov)[1:nbeta] <- colnames(mod$x)
	rownames(vcov)[-(1:nbeta)] <- colnames(vcov)[-(1:nbeta)] <- mod$varcomps.names

	vcov
}

#just display the variance components
varcomps<-function(object,...){

	mod<-object
   	stopifnot(inherits(mod, "glmm"))
	coefficients<-mod$nu
	coefficients
}

#confidence intervals
confint.glmm<-function(object,parm,level=.95,...){
   	stopifnot(inherits(object, "glmm"))

	cf<-c(coef(object),varcomps(object))
	pnames<-names(cf)
	if(missing(parm)) parm<-pnames
	else if (is.numeric(parm)) parm<-pnames[parm]
	stopifnot(parm %in% pnames)

	a<-(1-level)/2
	a<-c(a,1-a)
	fac<-qnorm(a)
	pct<-a*100
	
	betaandnu<-c(object$beta,	nu<-object$nu)
	hessian<-object$loglike.hessian
	if(det(hessian)==0) {
            warning(paste("estimated Fisher information matrix not positive",
               "definite, making all standard errors infinite"))
            all.ses <- rep(Inf, nrow(hessian))
    }else{	
		varcov <-vcov.glmm(object)
		all.ses<-sqrt(diag(varcov))
		}
	
	names(all.ses)<-pnames
	ci<-matrix(data=NA,nrow=length(parm),ncol=2)
	colnames(ci)<-a
	rownames(ci)<-parm
	ci[,1]<-betaandnu[parm]+fac[1]*all.ses[parm]
	ci[,2]<-betaandnu[parm]+fac[2]*all.ses[parm]

	ci
}

# isolate the MC log likelihood evaluated at the MCMLEs
logLik.glmm<-function(object,...){

   	stopifnot(inherits(object, "glmm"))
	object$loglike.value
}

