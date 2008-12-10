function genRunDemos
% This script automatically generates the runDemos.m file, which contains
% code to run every demo in BLT. It searches through every class method and
% includes those methods that have the string '#demo' as the first word in
% the method comment, just below the header as in
%
%    function a = func(b,c)
%    %#demo 
%
% Additional comments can follow. 
% Each included method is written to the runDemos file as in
%
%    methodName1(className1);
%    methodName2(className2);
%
% and must therefore be capable of running as such. No checks are performed
% to ensure that this is the case. 
%
% If runDemos.m already exists, it is renamed runDemos.old . If there is
% already a runDemos.old file, it is overwritten. 
%
% This function will only work on windows systems. Run this script from the
% top level BLT directory.

error('Deprecated - use makeRunDemos() instead');

filename = 'runDemos';    %The name of the generated m-file.
checkstr = '#demo';       %The method comment search string. 


flist = dir;
files = {flist.name};

%Rename existing runDemos.m
if(ismember([filename,'.m'],files))
   fprintf(['\nrenaming ',filename,'.m as ',filename,'.old ...\n']);
   if(ismember([filename,'.old'],files))
       eval(['!del ',filename,'.old']);
   end
   eval(['!rename ',filename,'.m ',filename,'.old']);
end

%Open file
fid = fopen([filename,'.m'],'w');
fprintf(fid,'%%Code automatically generated by genRunDemos.\n%%Run all BLT demos.\n');


%Get all of the classes
info = dirinfo('.');
classes = vertcat(info.classes);    


%Search through every method of every class for the comment search string.
for i=1:numel(classes)
    try
        meta = eval(['?',classes{i}]);
        methods = meta.Methods;
        for m =1: numel(methods)
           method = methods{m};
           check = strtok(help([classes{i},'.',method.Name]));  %Only look at the first token
           if(strcmp(checkstr,check));
              fprintf(fid,[method.Name,'(',classes{i},');\n']); %Write method call to file
           end
        end
    catch ME
        warning('CLASSTREE:discoveryWarning',['Could not discover information about class ',classes{i}]);
        continue;
    end
end
fprintf(fid,'\n');
fclose(fid);

    
    
    
    
    
    
    
function info = dirinfo(directory)
%Recursively generate an array of structures holding information about each
%directory/subdirectory beginning with, (and including) the initially specified
%parent directory. 
        info = what(directory);
        flist = dir(directory);
        dlist =  {flist([flist.isdir]).name};
        for i=1:numel(dlist)
            dirname = dlist{i};
            if(~strcmp(dirname,'.') && ~strcmp(dirname,'..'))
               info = [info, dirinfo([directory,'\',dirname])]; 
            end
        end
end








end