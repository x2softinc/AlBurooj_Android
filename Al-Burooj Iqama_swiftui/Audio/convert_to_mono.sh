#!/bin/bash
   # Convert all CAF files to mono
   
   for caffile in *.caf; do
       echo "Converting $caffile to mono..."
       
       # Create backup
       mv "$caffile" "${caffile}.backup"
       
       # Convert to mono
       afconvert -f caff -d LEI16@44100 -c 1 "${caffile}.backup" "$caffile"
       
       if [ $? -eq 0 ]; then
           echo "✅ $caffile converted successfully"
           rm "${caffile}.backup"
       else
           echo "❌ Failed to convert $caffile"
           mv "${caffile}.backup" "$caffile"
       fi
   done
   
   echo "🎉 All files processed!"
