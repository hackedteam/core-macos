#include <stdio.h>
#include <dirent.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <openssl/sha.h>

#include <sqlite3.h>


#define IN_SMS        2
#define OUT_SMS       3
#define TimeIntervalSince1970 978307200.0
#define WA_CHAT       1   // TODO: define this
#define SKYPE_CHAT    2   // TODO: define this
#define VIBER_CHAT    3   // TODO: define this
#define MESSAGES_CHAT 4   // TODO: define this


char gWAusername[128];  // TODO: move as NString in .h

#pragma mark -
#pragma mark Structures
#pragma mark -

typedef struct contactRecord  // TODO: define this
{
    char *firstName;
    char *lastName;
    char *cellPhone[10];
    char *homePhone[10];
    char *mailAddr[10];
    int local;   // 1 if it's my telephone number, 0 otherwise
    
} contactRecord;

typedef struct callRecord
{
    char *address;
    int duration;
    int flags;       // incoming = 1, outgoing = 0
    long epochTime;
} callRecord;

typedef struct chatRecord
{
    char *from;
    char *to;
    char *text;
    int flags;   // incoming = 1, outgoing = 0
    int type;    // whatsapp, skype, viber....
    long epochTime;

} chatRecord;

typedef struct attachRecord
{
    char *from;
    char *to;
    char *filename;
    char *transferName;
    char *mimeType;
    int flags;   // incoming = 1, outgoing = 0
    int type;    // whatsapp, skype, viber....
    long epochTime;
    
} attachRecord;

typedef struct photoRecord
{
    char *photoName;
    char *bkupName;
    long epochTime;
} photoRecord;

typedef struct smsRecord
{
    char *from;
    char *to;
    char *text;
    int flags;
    long epochTime;
} smsRecord;

typedef struct mbdbRecord
{
    char *sha1;
    char *filename;
    struct mbdbRecord *next;

} mbdbRecord;


void freeMbdbRecord(mbdbRecord *record)
{
    if(record != NULL)
    {
        free(record->sha1);
        free(record->filename);
        free(record);
    }
}

void deleteMbdbRecordList(mbdbRecord *headRef)
{
    mbdbRecord *current = headRef;
    mbdbRecord *next;
    while (current != NULL)
    {
        next = current->next;
        freeMbdbRecord(current);
        current = next;
    }
}



char* stringFromHex(unsigned char byteArray[])
{
    char *hexString = (char *)calloc(2*SHA_DIGEST_LENGTH+1,sizeof(char));
    for (int i=0; i<SHA_DIGEST_LENGTH; ++i)
    {
        sprintf(hexString+2*i,"%02X",byteArray[i]);
    }
    return hexString;
}


void freeBkupArray(char **array)
{
    if(array != NULL)
    {
        int i=0;
        while (*(array+i) != NULL)
        {
            free(*(array+i));
            ++i;
        }
        free(array);
    }
}

#pragma mark -
#pragma mark Mbdb stuff
#pragma mark -

// retrieve string from buffer, first 2 bytes contain string length
int getString(char **string,char *buffer)
{
    uint16_t len = ntohs(*((uint16_t*)buffer));
    if (len != 0xffff)
    {
        *string = calloc(len+1,sizeof(uint8_t));
        if(*string != NULL)
        {
            strncpy(*string, buffer+2, len);
        }
    
        return len+2;
    }
    else
        return 2;
}

// parse mbdb file given UDID path and create linked list of info
int parseMbdbFile(mbdbRecord **head, char *udidPath)
{
    // retrieve mbdb file path
    if (udidPath == NULL)
    {
        return -1;
    }
    
    char *completePath = malloc(sizeof(char)*(strlen(udidPath)+strlen("Manifest.mbdb")+strlen("/"))+1);
    if (completePath == NULL)
    {
        return -1;
    }
    
    if(sprintf(completePath,"%s/%s",udidPath,"Manifest.mbdb") < 0)
    {
        free(completePath);
        return -1;
    }
    
    // open file
    int fd = open(completePath, O_RDONLY);
    if ( fd < 0 )
    {
        free(completePath);
        return -1;
    }

    free(completePath);
    
    // read file
    struct stat fd_stat;
    if(fstat(fd, &fd_stat) <0)
    {
        close(fd);
        return -1;
    }
    char *buff = NULL;
    if((buff=malloc(fd_stat.st_size)) == NULL)
    {
        close(fd);
        return -1;
    }
    int n;
    if((n=read(fd, buff, fd_stat.st_size))<0)
    {
        free(buff);
        close(fd);
        return -1;
    }
    
    // close file
    close(fd);
    
    // parse
    // take signature
    char signature[6];
    memcpy(signature,buff,6);
    if (strncmp(signature,"mbdb",4)!=0)
    {
        // not an mbdb file
        free(buff);
        return -1;
    }
    // start cycling on mbdb file
    int i =6;
    while(i < fd_stat.st_size)
    {
        // retrieve domain string
        char *domain = NULL;
        int len = getString(&domain,buff+i);
        i = i+len;
        
        // retrieve path string
        char *path = NULL;
        len = getString(&path,buff+i);
        i = i+len;

        // retrieve backup filename: sha1 of "domain - path"
        char *gluedName=NULL;
        gluedName = calloc(strlen(domain) + strlen(path) + strlen("-") + 1,sizeof(char));
        sprintf(gluedName,"%s-%s",domain,path);
        unsigned char hash[SHA_DIGEST_LENGTH];
        SHA1((const unsigned char*)gluedName, strlen(gluedName), hash);
        free(gluedName);
        free(domain);
        
        char *hashString = stringFromHex(hash);
        if (hashString == NULL)
        {
            free(path);
            continue;
        }
        char *completeHash = calloc(strlen(udidPath)+strlen("/")+2*SHA_DIGEST_LENGTH+1,sizeof(char));
        if (completeHash == NULL)
        {
            free(hashString);
            free(path);
            continue;
        }
        if (sprintf(completeHash,"%s/%s",udidPath,hashString)<0)
        {
            free(completeHash);
            free(hashString);
            free(path);
            continue;
        }
        free(hashString);
        
        // retrieve target
        char *target = NULL;
        len = getString(&target,buff+i);
        free(target);
        i = i+len;
        
        // retrieve digest
        char *digest = NULL;
        len = getString(&digest,buff+i);
        free(digest);
        i = i+len;
        
        // retrieve key
        char *key = NULL;
        len = getString(&key,buff+i);
        free(key);
        i = i+len;
        
        // mode: 0x8XXX is a regular file
        int isFile = 0;
        if(((uint8_t)*(buff+i) & 0xf0)==0x80)
        {
            isFile = 1;
        }
        /*
        i += 2; // mode
        i += 8; // inode
        i += 4; // user id
        i += 4; // group id
        i += 4; // last modified time
        i += 4; // last accessed time
        i += 4; // creation time
        i += 8; // size
        i += 1; // protection class
         */
        i += 39;
        if (isFile)
        {
            mbdbRecord *newRecord = calloc(1,sizeof(mbdbRecord));
            if (newRecord != NULL)
            {
                if (completeHash!=NULL)
                {
                    if((newRecord->sha1 = calloc(strlen(completeHash)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(newRecord->sha1,completeHash);
                    }
                }
                if (path!=NULL)
                {
                    if((newRecord->filename = calloc(strlen(path)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(newRecord->filename,path);
                    }
                }
                newRecord->next = *head;
                *head = newRecord;
            }
        }
        
        free(path);
        free(completeHash);
        
        // retrieve num of properties
        // every property is a couple name-value
        uint8_t prop_num = *(buff+i);
        i += 1;
        for(int j=0; j<prop_num; ++j)
        {
            char *name = NULL;
            len = getString(&name,buff+i);
            i = i+len;

            char *value = NULL;
            len = getString(&value,buff+i);
            i = i+len;

            free(name);
            free(value);
        }
    }
    
    free(buff);
    
    return 1;
}

#pragma mark -
#pragma mark Directories stuff
#pragma mark -


// give back backups home: "<home dir>/Library/Application Support/MobileSync/Backup"
// remember to free memory
// TODO: platform specific code
char* getBkupsHome()
{
    // TODO: platform specific code
    // backups are in:
    // <home dir>/Library/Application Support/MobileSync/Backup/<UDID>/
    // retrieve Application Support directory
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    //NSString *applicationSupportDirectory = [paths firstObject];
    
    int l = strlen("/Users/monkeymac/Library/Application Support/MobileSync/Backup");
    char *home = malloc(sizeof(char)*l+1);
    if (home != NULL)
    {
        strcpy(home,"/Users/monkeymac/Library/Application Support/MobileSync/Backup");
    }
    return home;
}

// collect all bkup dirs and allocate an array of strings
// remember to free the array when finished
char** getBackupDirs(void)
{
    // backups are in:
    // <home dir>/Library/Application Support/MobileSync/Backup/<UDID>/
    
    char *bkupsDirName = getBkupsHome(); // <home dir>/Library/Application Support/MobileSync/Backup
    
    if (bkupsDirName == NULL)
    {
        return NULL;
    }
    
    DIR *bkupsDir;
    struct dirent *entry;
    
    if ((bkupsDir = opendir(bkupsDirName)) == NULL)
    {
        free(bkupsDirName);
        return NULL;
    }
    int count = 0;
    
    // find how many entries has the backup dir
    while ((entry = readdir(bkupsDir) )!= NULL)
    {
        if (entry->d_type == DT_DIR)
        {
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                continue;
            ++count;
        }
    }
    
    // allocate array
    char **dirArray = NULL;
    if (count >0)
    {
        dirArray = (char**)calloc(count+1,sizeof(char*));
    }
    
    if (dirArray != NULL)
    {
        // reset the position of the directory stream
        rewinddir(bkupsDir);
        // fill array
        int i = 0;
        while ((entry = readdir(bkupsDir) )!= NULL)
        {
            if (entry->d_type == DT_DIR)
            {
                if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                    continue;
                int len = sizeof(char)*(strlen(bkupsDirName)+strlen(entry->d_name)+strlen("/"));
                if((*(dirArray+i) = calloc(len+1,sizeof(char)))!=NULL)
                {
                    //memset(*(dirArray+i),0,len+1);
                    sprintf(*(dirArray+i),"%s/%s",bkupsDirName,entry->d_name);
                    ++i;
                }
            }
        }
    }
    
    // close the directory stream
    closedir(bkupsDir);
    
    // free mem
    free(bkupsDirName);
    
    return dirArray;
}

// returns 1 if the string t occurs at the end of the string s, and 0 otherwise.
int strend(const char *s, const char *t)
{
    if ((s == NULL) || (t == NULL))
    {
        return 0;
    }
    size_t ls = strlen(s); // find length of s
    size_t lt = strlen(t); // find length of t
    if (ls >= lt)  // check if t can fit in s
    {
        // point s to where t should start and compare the strings from there
        return (0 == memcmp(t, s + (ls - lt), lt));
    }
    return 0; // t was longer than s
}

#pragma mark -
#pragma mark Sms stuff
#pragma mark -

// TODO: put here platform specific code
void logSms(smsRecord *sms)
{
    if (sms == NULL)
    {
        return;
    }
    printf("****\n");
    printf("From: %s\n", sms->from);
    printf("To: %s\n", sms->to);
    printf("Text: %s\n", sms->text);
    printf("Flags: %d\n", sms->flags);
    printf("Epoch: %ld\n", sms->epochTime);
}

int parseSmsDb(char *dbName, long epochMarkup)
{
    sqlite3       *db = NULL;
    int           ret, nrow = 0, ncol = 0;
    int           osVer = 0;
    long          date = 0;
    char          *szErr;
    char          **result;
    
    char          sql_query_curr[1024];
    char          sql_query_ios3[] = "select date,address,text,flags,ROWID from message";
    char          sql_query_ios6[] = "select message.date,chat.chat_identifier, message.text, message.is_from_me,message.rowid from message inner join chat_message_join on chat_message_join.message_id = message.rowid inner join chat on chat_message_join.chat_id = chat.rowid where message.service = 'SMS' and ";
    
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // first, try query as version  6
    if ((date = (epochMarkup - TimeIntervalSince1970)) <0 )  // in ios >= 6, date is in mac absolute time
    {
        date = 1;
    }
    sprintf(sql_query_curr, "%s message.date >= %ld", sql_query_ios6, date);
    
    if (sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr) != SQLITE_OK)
    {
        sqlite3_free_table(result);
        free(szErr);
        date = epochMarkup;
        sprintf(sql_query_curr, "%s message.date >= %ld", sql_query_ios3, date);
        if (sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr) != SQLITE_OK)
        {
            sqlite3_free_table(result);
            free(szErr);
            sqlite3_close(db);
            return -1;
        }
    }
    else
    {
        osVer = 6;
    }
    
    // close db
    sqlite3_close(db);
    
    // Only if we got some msg...
    if (ncol * nrow > 0)
    {
        for (int i = 0; i< nrow * ncol; i += 5)
        {
            smsRecord newRecord;
            
            // flags == 2 -> in mesg; flags == 3 -> out mesg; flags == 33,35 out msg not sent
            int flags = 0;
            char *__flags = result[ncol + i + 3] == NULL ? "0" : result[ncol + i + 3];
            
            sscanf(__flags, "%d", &flags);
            
            switch (flags)
            {
                case IN_SMS:  // "flags" column in os version <6
                case 0:       // "is_from_me" column in os version >= 6
                {
                    if (result[ncol + i + 1] != NULL)
                        newRecord.from = result[ncol + i + 1];
                    else
                        newRecord.from = NULL;
                    
                    newRecord.flags = 1;
                    newRecord.to = "local";  // TODO: insert phone number if/when possible
                    break;
                }
                case OUT_SMS: // "flags" column in os version <6
                case 33:      // "flags" column in os version <6
                case 35:      // "flags" column in os version <6
                case 1:       // "is_from_me" column in os version >= 6
                {
                    if (result[ncol + i + 1] != NULL)
                        newRecord.to = result[ncol + i + 1];
                    else
                        newRecord.to = NULL;
                    newRecord.flags = 0;
                    newRecord.from = "local"; // TODO: insert phone number if/when possible
                    break;
                }
                default:
                    break;
            }
            
            // text of the sms
            newRecord.text = result[ncol + i + 2] == NULL ? NULL : result[ncol + i + 2];
            
            // timestamp of the sms
            long ts;
            char *_ts  = result[ncol + i] == NULL ? "0" : result[ncol + i];
            sscanf(_ts, "%ld", &ts);
            newRecord.epochTime = ts;
            if (osVer >= 6)
            {
                newRecord.epochTime += TimeIntervalSince1970;
            }
            
            // log sms
            logSms(&newRecord);
            
        }
    }
    
    // free result table
    sqlite3_free_table(result);

    return 1;
}

int collectSms(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"sms.db"))
        {
            printf("found sms.db\n"); // TODO: delete this
            printf("filename: %s\n",current->sha1);  // TODO: delete this
            parseSmsDb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

#pragma mark -
#pragma mark Photos stuff
#pragma mark -


// TODO: put here platform specific code
void logPhoto(photoRecord *photo)
{
    if (photo == NULL)
    {
        return;
    }
    printf("****\n");
    printf("Photo name: %s\n", photo->photoName);
    printf("Backup name: %s\n", photo->bkupName);
    printf("Epoch: %ld\n", photo->epochTime);
}

int parsePhotosDb(mbdbRecord *head, char *dbName, long epochMarkup)
{
    sqlite3       *db = NULL;
    int           ret, nrow = 0, ncol = 0;
    char          *szErr = NULL;
    char          **result;
    
    char          sql_query_curr[1024];
    char          sql_query_ios5[] = "select ZFILENAME,ZDATECREATED from ZGENERICASSET";
    char          sql_query_ios4[] = "select filename,captureTime from Photo";
    
    // build real sql query
    long date = epochMarkup;
    if ((date -= TimeIntervalSince1970) <0 )  // date in db is in mac absolute time
    {
        date = 1;
    }
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // first, try query as version  5
    sprintf(sql_query_curr, "%s where ZDATECREATED >= %ld", sql_query_ios5, date);
    
    if (sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr) != SQLITE_OK)
    {
        sqlite3_free_table(result);
        free(szErr);
        sprintf(sql_query_curr, "%s where captureTime >= %ld", sql_query_ios4, date);
        if (sqlite3_get_table(db, sql_query_curr, &result, &nrow, &ncol, &szErr) != SQLITE_OK)
        {
            sqlite3_free_table(result);
            free(szErr);
            sqlite3_close(db);
            return -1;
        }
    }
    
    // close db
    sqlite3_close(db);
    
    // Only if we got some photo...
    if (ncol * nrow > 0)
    {
        for (int i = 0; i< nrow * ncol; i += 2)
        {
            photoRecord newRecord;
            
            // photo name
            char *photoName = result[ncol + i] == NULL ? NULL : result[ncol + i];
            newRecord.photoName = photoName;
            
            // timestamp of the photo
            long ts;
            char *_ts  = result[ncol + i + 1] == NULL ? "0" : result[ncol + i + 1];
            sscanf(_ts, "%ld", &ts);
            newRecord.epochTime = ts+TimeIntervalSince1970;

            // photo backupname
            mbdbRecord *current = head;
            int found = 0;
            while (current!=NULL && !found)
            {
                if (strend(current->filename,photoName))
                {
                    newRecord.bkupName = current->sha1;
                    found = 1;
                }
                current = current->next;
            }

            // log photo
            logPhoto(&newRecord);
        }
    }
    
    // free result table
    sqlite3_free_table(result);
    
    return 1;
}

int collectPhotos(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"Photos.sqlite"))
        {
            printf("found photo db\n");  // TODO: delete this
            printf("filename: %s\n",current->sha1);  // TODO: delete this
            parsePhotosDb(head, current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

// TODO: put here platform specific code
void logChat(chatRecord *msg)
{
    if (msg == NULL)
    {
        return;
    }
    printf("****\n");
    printf("From: %s\n", msg->from);
    printf("To: %s\n", msg->to);
    printf("Text: %s\n", msg->text);
    printf("Flags: %d\n", msg->flags);
    printf("Type: %d\n", msg->type);
    printf("Epoch: %ld\n", msg->epochTime);
}

void logAttach(attachRecord *att)
{
    if (att == NULL)
    {
        return;
    }
    printf("****\n");
    printf("From: %s\n", att->from);
    printf("To: %s\n", att->to);
    printf("File name: %s\n", att->filename);
    printf("Transfer name: %s\n", att->transferName);
    printf("Flags: %d\n", att->flags);
    printf("Type: %d\n", att->type);
    printf("Epoch: %ld\n", att->epochTime);
}

#pragma mark -
#pragma mark WhatsApp
#pragma mark -

// TODO: platform specific, use NSDictionary in osx
int setWAUserName(mbdbRecord *head)
{
    strcpy(gWAusername,"me");
    return 1;
    /*
    NSString *rootPath = [self getWARootPathName];
    
    if (rootPath != nil)
    {
        NSString *WAPrefsPath =
        [NSString stringWithFormat:@"%@/Library/Preferences/net.whatsapp.WhatsApp.plist",
         rootPath];
        [rootPath release];
        
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile: WAPrefsPath];
        
        if (prefs != nil && [prefs objectForKey: @"OwnJabberID"] != nil)
        {
            NSString *tmpWAUsername = [prefs objectForKey: @"OwnJabberID"];
            
            mWAUsername = [[NSString alloc] initWithString: [self getWAPhoneNumber: tmpWAUsername]];
        }
    }*/
}

int isAGroup(char *name)
{
    if (name == NULL)
        return 0;
    
    if(strstr(name,"-") != NULL)
        return 1;
    else
        return 0;
}


int parseWADb(char *dbName, long epochMarkup)
{
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
 
    char query[256];
    long date = epochMarkup;
    char _query[] =
    "select ZTEXT, ZISFROMME, ZGROUPMEMBER, ZFROMJID, ZTOJID, Z_PK, ZCHATSESSION, ZMESSAGEDATE from ZWAMESSAGE where ZMESSAGEDATE >";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // construct query
    if ((date -= TimeIntervalSince1970) <0 )  // date in db is in mac absolute time
    {
        date = 1;
    }
    sprintf(query, "%s %ld", _query, date);
    
    if(sqlite3_prepare_v2(db, query, strlen(query) + 1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_finalize(stmt);
        sqlite3_close(db);
        return -1;
    }
  
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        chatRecord msg;
        
        memset(&msg,0,sizeof(chatRecord));
        
        // text
        char *_text = (char *)sqlite3_column_text(stmt,0);
        
        if (_text == NULL)
            continue;
        // text
        if ((msg.text = calloc(strlen(_text) +1, sizeof(char))) != NULL)
        {
            strcpy(msg.text,_text);
        }
        // chat type
        msg.type = WA_CHAT;
        // chat date
        msg.epochTime = sqlite3_column_double(stmt,7);
        msg.epochTime += TimeIntervalSince1970;
        // in,out flags
        int fromMe = sqlite3_column_int(stmt,1);
        msg.flags = ((fromMe == 1)? 0x00000000 : 0x00000001);
        // from, to
        if (fromMe == 1)
        {
            // msg is from me
            if((msg.from = calloc(strlen(gWAusername)+1,sizeof(char)))!=NULL)
            {
                strcpy(msg.from, gWAusername);
            }
            // recipients can be a single user or a group
            char *_to = (char *)sqlite3_column_text(stmt, 4); //ZTOJID
            if(isAGroup(_to))
            {
                // recipient is a group
                int zchtsess = sqlite3_column_int(stmt, 6);
                sqlite3_stmt *stmt2;
                char query[128];
                
                char _query[] = "select ZMEMBERJID from ZWAGROUPMEMBER where ZCHATSESSION = ";
                sprintf(query, "%s %d", _query, zchtsess);
                
                if(sqlite3_prepare_v2(db, query, strlen(query)+1, &stmt2, NULL) == SQLITE_OK)
                {
                    while (sqlite3_step(stmt2) == SQLITE_ROW)
                    {
                        char *member = (char *)sqlite3_column_text(stmt2,0);
                        if (member == NULL)
                            continue;
                            
                        if (msg.to == NULL)
                        {
                            // first member
                            if ((msg.to = calloc(strlen(member)+1,sizeof(char)))!=NULL)
                            {
                                strcpy(msg.to,member);
                            }
                        }
                        else
                        {
                            char *new = realloc(msg.to,sizeof(char)*strlen(msg.to)+sizeof(char)*strlen(member)+sizeof(char)*strlen(";")+1);
                            if (new != NULL)
                            {
                                msg.to = new;
                                strcat(msg.to, ";");
                                strcat(msg.to,member);
                            }
                        }
                    }
                }
                    
                // free sqlite resources
                sqlite3_finalize(stmt2);
            }
            else
            {
                // recipient is not a group
                if(_to != NULL)
                {
                    if ((msg.to = calloc(strlen(_to)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(msg.to,_to);
                    }
                }
            }
        }
        else
        {
            // msg is not from me
            // sender could be a group
            char *_from = (char *)sqlite3_column_text(stmt, 3); //ZFROMJID
            if(isAGroup(_from))
            {
                // sender is a group
                int zchtsess = sqlite3_column_int(stmt, 6);
                sqlite3_stmt *stmt2;
                char query[128];
                
                char _query[] = "select ZMEMBERJID from ZWAGROUPMEMBER where ZCHATSESSION = ";
                sprintf(query, "%s %d", _query, zchtsess);
                
                if(sqlite3_prepare_v2(db, query, strlen(query)+1, &stmt2, NULL) == SQLITE_OK)
                {
                    while (sqlite3_step(stmt2) == SQLITE_ROW)
                    {
                        char *member = (char *)sqlite3_column_text(stmt2,0);
                        if (member == NULL)
                            continue;
                        
                        if (msg.from == NULL)
                        {
                            // first member
                            if ((msg.from = calloc(strlen(member)+1,sizeof(char)))!=NULL)
                            {
                                strcpy(msg.from,member);
                            }
                        }
                        else
                        {
                            char *new = realloc(msg.from,sizeof(char)*(strlen(msg.from)+strlen(member)+strlen(";"))+1);
                            if (new != NULL)
                            {
                                msg.from = new;
                                strcat(msg.from, ";");
                                strcat(msg.from,member);
                            }
                        }
                    }
                }
                
                // free sqlite resources
                sqlite3_finalize(stmt2);
            }
            else
            {
                // sender is not a group
                if(_from != NULL)
                {
                    if ((msg.from = calloc(strlen(_from)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(msg.from,_from);
                    }
                }
            }
            
            // recipient could be a group
            char *_to = (char *)sqlite3_column_text(stmt, 4); //ZTOJID
            if(isAGroup(_to))
            {
                // recipient is a group
                int zchtsess = sqlite3_column_int(stmt, 6);
                sqlite3_stmt *stmt2;
                char query[128];
                
                char _query[] = "select ZMEMBERJID from ZWAGROUPMEMBER where ZCHATSESSION = ";
                sprintf(query, "%s %d", _query, zchtsess);
                
                if(sqlite3_prepare_v2(db, query, strlen(query)+1, &stmt2, NULL) == SQLITE_OK)
                {
                    while (sqlite3_step(stmt2) == SQLITE_ROW)
                    {
                        char *member = (char *)sqlite3_column_text(stmt2,0);
                        if (member == NULL)
                            continue;
                        
                        if (msg.to == NULL)
                        {
                            // first member
                            if ((msg.to = calloc(strlen(member)+1,sizeof(char)))!=NULL)
                            {
                                strcpy(msg.to,member);
                            }
                        }
                        else
                        {
                            char *new = realloc(msg.to,sizeof(char)*(strlen(msg.to)+strlen(member)+strlen(";"))+1);
                            if (new != NULL)
                            {
                                msg.to = new;
                                strcat(msg.to, ";");
                                strcat(msg.to,member);
                            }
                        }
                    }
                }
                
                // free sqlite resources
                sqlite3_finalize(stmt2);
            }
            else
            {
                // recipient is not a group
                if (_to != NULL)  // it's a single user
                {
                    if ((msg.to = calloc(strlen(_to)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(msg.to,_to);
                    }
                }
                else  // it's me
                {
                    if ((msg.to = calloc(strlen(gWAusername)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(msg.to,gWAusername);
                    }
                }
            }
                
        }
        // log
        logChat(&msg);
        // free allocated mem
        free(msg.from);
        free(msg.to);
        free(msg.text);
    }

    // free sqlite resources
    sqlite3_finalize(stmt);
    
    // close db
    sqlite3_close(db);
     
    return 1;
}

int collectWhatsApp(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    // retrieve local username  from plist
    setWAUserName(head);
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"ChatStorage.sqlite"))
        {
            printf("found wa db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseWADb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

#pragma mark -
#pragma mark Viber
#pragma mark -

int parseViberDb(char *dbName, long epochMarkup)
{
    if (dbName == NULL)
    {
        return -1;
    }
    
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    char query[256];
    long date = epochMarkup;
    char _query[] = "select ztext, zstate, zdate, zconversation, zphonenum from zvibermessage left outer join zphonenumberindex  on zphonenumindex=zphonenumberindex.z_pk where zdate >";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // construct query
    if ((date -= TimeIntervalSince1970) <0 )  // date in db is in mac absolute time
    {
        date = 1;
    }
    sprintf(query, "%s %ld", _query, date);

    if(sqlite3_prepare_v2(db, query, -1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_finalize(stmt);
        sqlite3_close(db);
        return -1;
    }

    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        chatRecord msg;
        memset(&msg,0,sizeof(chatRecord));
        
        // text
        msg.text = (char *)sqlite3_column_text(stmt,0);
        if (msg.text == NULL)
            continue;
        // chat type
        msg.type = VIBER_CHAT;
        // chat date
        msg.epochTime = sqlite3_column_double(stmt,2);
        msg.epochTime += TimeIntervalSince1970;
        // sender when msg incoming
        char *_from = (char *)sqlite3_column_text(stmt,4);
        // peer
        sqlite3_stmt *stmt2 = NULL;
        char inner_query[256];
        int conversation  = sqlite3_column_int(stmt,3);
        
        char _inner_query_3[] = "select zphonenumberindex.zphonenum from zphonenumberindex,z_3phonenumindexes where z_3phonenumindexes.z_5phonenumindexes =  zphonenumberindex.z_pk and z_3phonenumindexes.z_3conversations =";
        char _inner_query_4[] = "select zphonenumberindex.zphonenum from zphonenumberindex,z_4phonenumindexes where z_4phonenumindexes.z_6phonenumindexes =  zphonenumberindex.z_pk and z_4phonenumindexes.z_4conversations =";
        char *peer = NULL;
        int ok = 0;
        sprintf(inner_query, "%s %d", _inner_query_4, conversation);
        if(sqlite3_prepare_v2(db, inner_query, -1, &stmt2, NULL) == SQLITE_OK)
        {
            ok = 1;
        }
        else
        {
            sqlite3_finalize(stmt2);
            sprintf(inner_query, "%s %d", _inner_query_3, conversation);
            if(sqlite3_prepare_v2(db, inner_query, -1, &stmt2, NULL) == SQLITE_OK)
            {
                ok = 1;
            }
        }
        if (ok)
        {
            while (sqlite3_step(stmt2) == SQLITE_ROW)
            {
                char *phone = (char *)sqlite3_column_text(stmt2,0);
                if (phone == NULL)
                    continue;
                int add = 1;
                if(_from != NULL)
                {
                    if (strcmp(_from,phone) == 0)
                    {
                        add = 0;
                    }
                }
                if (add)
                {
                    if (peer == NULL)
                    {
                        // first run
                        if ((peer = calloc(strlen(phone)+1,sizeof(char)))!=NULL)
                        {
                            strcpy(peer,phone);
                        }
                    }
                    else
                    {
                        peer = realloc(peer,sizeof(char)*(strlen(peer)+strlen(phone)+strlen(";"))+1);
                        if (peer != NULL)
                        {
                            //peer = new;
                            strcat(peer, ";");
                            strcat(peer,phone);
                        }
                    }
                }
            }
        }
        sqlite3_finalize(stmt2);

        // in, out flags;  to,from
        char *_state = (char *)sqlite3_column_text(stmt,1);
        if ((strncmp(_state,"delivered",strlen("delivered")) ==0) || (strncmp(_state,"send",strlen("send")) ==0))
        {
            // out
            msg.flags = 0x00000000;
            if(peer != NULL)
            {
                if((msg.to = calloc(strlen(peer)+1,sizeof(char))) != NULL)
                {
                    strcpy(msg.to,peer);
                }
            }
            if((msg.from = malloc(sizeof(char)*strlen("me")+1)) != NULL)  // TODO: find real phone number
                strcpy(msg.from,"me");
        }
        else
        {
            // in
            msg.flags = 0x00000001;
            if(_from!=NULL)
            {
                if((msg.from = malloc(sizeof(char)*strlen(_from)+1)) != NULL)
                    strcpy(msg.from,_from);
            }
            // add peer if not null
            if (peer != NULL)
            {
                if (msg.to == NULL)
                {
                    // first run
                    if ((msg.to = calloc(strlen(peer)+1,sizeof(char)))!=NULL)
                    {
                        strcpy(msg.to,peer);
                    }
                }
                else
                {
                    char *new = realloc(msg.to,sizeof(char)*(strlen(msg.to)+strlen(peer)+strlen(";"))+1);
                    if (new != NULL)
                    {
                        msg.to = new;
                        strcat(msg.to, ";");
                        strcat(msg.to,peer);
                    }
                }
            }
        }
        free(peer);
        // log
        logChat(&msg);
        // free allocated mem
        free(msg.to);
        free(msg.from);
        
    }
    
    // free sqlite resources
    sqlite3_finalize(stmt);

    // close db
    sqlite3_close(db);
    
    return 1;
}


int collectViber(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"Contacts.data"))
        {
            printf("found viber db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseViberDb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

#pragma mark -
#pragma mark Skype
#pragma mark -

// replace old with new in origin
// free resulting string
char* replaceChr(char *origin, char *old, char *new)
{
    char *result = NULL;
    
    if ((origin == NULL) || (old == NULL) || (new == NULL))
        return result;
    
    result = calloc(strlen(origin)+1,sizeof(char));
    if (result != NULL)
    {
        strcpy(result,origin);
        char *tmp = NULL;
        char *ptr = result;
        while ((tmp=strstr(ptr,old)) != NULL)
        {
            memcpy(tmp,new,sizeof(char));
            ptr = tmp + sizeof(char);
        }
    }
    return result;
}

int parseSkypeDb(char *dbName, long epochMarkup)
{
    if (dbName == NULL)
    {
        return -1;
    }
    
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    char query[256];
    long date = epochMarkup;
    char _query[] = "select Messages.body_xml, Messages.author, Messages.dialog_partner, Messages.id, Chats.participants, Messages.chatmsg_status, Messages.timestamp from Messages inner join Chats on Chats.name = Messages.chatname where Messages.timestamp >";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // construct query
    // timestamp in db is in epoch
    sprintf(query, "%s %ld", _query, date);
    
    if(sqlite3_prepare_v2(db, query, -1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_close(db);
        return -1;
    }
    
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        chatRecord msg;
        memset(&msg,0,sizeof(chatRecord));
        
        // text
        msg.text = (char *)sqlite3_column_text(stmt,0);
        if (msg.text == NULL)
            continue;
        // chat type
        msg.type = SKYPE_CHAT;
        // chat date - epoch time in skype db
        msg.epochTime = sqlite3_column_double(stmt,6);
        // in, out flags
        int direction = sqlite3_column_int(stmt,5);
        switch (direction) {
            case 1:
            case 2:
                {
                    // outgoing
                    msg.flags = 0x00000000;
                }
                break;
            case 3:
            case 4:
                {
                    // incoming
                    msg.flags = 0x00000001;
                }
                break;
            default:
                break;
        }
        // from
        msg.from = (char *)sqlite3_column_text(stmt,1);
        // to
        char *peer = (char *)sqlite3_column_text(stmt,2);
        if (peer == NULL)
        {
            // multichat
            char *_to = (char *)sqlite3_column_text(stmt,4);
            msg.to = replaceChr(_to," ",";");
        }
        else
        {
            // single peer
            if((msg.to = calloc(strlen(peer)+1,sizeof(char))) != NULL)
                strcpy(msg.to,peer);
        }
        // log
        logChat(&msg);
        // free allocated mem
        free(msg.to);
    }
    
    // free sqlite resources
    sqlite3_finalize(stmt);
    
    // close db
    sqlite3_close(db);
    
    return 1;
}

int collectSkype(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"main.db"))
        {
            printf("found skype db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseSkypeDb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

void logCall(callRecord *rec)
{
    if (rec == NULL)
    {
        return;
    }
    printf("****\n");
    printf("Address: %s\n", rec->address);
    printf("Duration: %d\n", rec->duration);
    printf("Flags: %d\n", rec->flags);
    printf("Epoch: %ld\n", rec->epochTime);
}

int parseCallDb(char *dbName, long epochMarkup)
{
    if (dbName == NULL)
    {
        return -1;
    }
    
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    char query[256];
    long date = epochMarkup;
    char _query[] = "select address, date, duration, flags from call where date >";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // construct query
    // timestamp in db is in epoch
    sprintf(query, "%s %ld", _query, date);
    
    if(sqlite3_prepare_v2(db, query, -1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_close(db);
        return -1;
    }
    
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        callRecord rec;
        memset(&rec,0,sizeof(callRecord));
        
        // address
        rec.address = (char *)sqlite3_column_text(stmt,0);
        // call date - epoch time
        rec.epochTime = sqlite3_column_double(stmt,1);
        // call duration - in seconds
        rec.duration = sqlite3_column_int(stmt,2);
        // call direction
        // all even values are incoming
        int dir = sqlite3_column_int(stmt,3);
        rec.flags = (dir%2 == 1)? 0:1;
        // log
        logCall(&rec);
    }
    
    // free sqlite resources
    sqlite3_finalize(stmt);
    
    // close db
    sqlite3_close(db);
    
    return 1;
}

int collectCallHistory(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"call_history.db"))
        {
            printf("found call_history db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseCallDb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}


int parseMessagesDb(mbdbRecord *head, char *dbName, long epochMarkup)
{
    if (dbName == NULL)
    {
        return -1;
    }
    
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    char query[1024];
    long date = epochMarkup;
    char _query[] = "select message.ROWID, message.date, message.text, message.is_from_me, message.handle_id, attachment.filename from message left outer join message_attachment_join on message.ROWID = message_attachment_join.message_id left outer join attachment on message_attachment_join.attachment_id = attachment.ROWID where message.service = 'iMessage' and message.date > ";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
    
    // construct query
    // timestamp in db is in mac absolute time
    if ((date -= TimeIntervalSince1970) <0 )
    {
        date = 1;
    }
    
    sprintf(query, "%s %ld", _query, date);
    
    if(sqlite3_prepare_v2(db, query, -1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_close(db);
        return -1;
    }
    
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        chatRecord msg;
        attachRecord att;
        memset(&msg,0,sizeof(callRecord));
        memset(&att,0,sizeof(attachRecord));
        
        // msgId
        int msgId = sqlite3_column_int(stmt,0);
        // handleId
        int msgHandleId = sqlite3_column_int(stmt,4);
        // msg date - mac absolute time
        msg.epochTime = sqlite3_column_double(stmt,1) + TimeIntervalSince1970;
        // msg flag, 1 incoming, 0 outgoing
        int fromMe = sqlite3_column_int(stmt,3);
        msg.flags = (fromMe == 1)? 0 : 1;
        // chat type
        msg.type = MESSAGES_CHAT;
        // chat text
        msg.text = (char *)sqlite3_column_text(stmt,2);
        if (fromMe == 1)
        {
            // outging msg
            // sender is me
            if((msg.from = malloc(sizeof(char)*strlen("me")+1)) != NULL)
                strcpy(msg.from,"me");
            
            // peer is chat participants
            sqlite3_stmt *stmt2 = NULL;
            char query2[1024];
            char _query2[] = "select handle.id from handle where handle.ROWID IN (select chat_handle_join.handle_id from chat_handle_join where chat_id = (select chat_id from chat_message_join where chat_message_join.message_id = ";
            sprintf(query2, "%s %d ))", _query2, msgId);
            
            if(sqlite3_prepare_v2(db, query2, -1, &stmt2, NULL) != SQLITE_OK)
            {
                continue;
            }
            while(sqlite3_step(stmt2) == SQLITE_ROW)
            {
                char *handleId = (char *)sqlite3_column_text(stmt2,0);
                
                if (handleId != NULL)
                {
                    if (msg.to == NULL)
                    {
                        // first contact
                        if ((msg.to = calloc(strlen(handleId)+1,sizeof(char)))!=NULL)
                        {
                            strcpy(msg.to,handleId);
                        }
                    }
                    else
                    {
                        // all subsequent contacts
                        char *new = realloc(msg.to,sizeof(char)*(strlen(msg.to)+strlen(handleId)+strlen(";"))+1);
                        if (new != NULL)
                        {
                            msg.to = new;
                            strcat(msg.to, ";");
                            strcat(msg.to,handleId);
                        }
                    }
                }
            }
            sqlite3_finalize(stmt2);
        }
        else
        {
            // incoming msg
            // sender is handle.id in handle
            sqlite3_stmt *stmt3 = NULL;
            char query3[256];
            char _query3[] = "select handle.id from handle where handle.ROWID = ";
            sprintf(query3, "%s %d", _query3, msgHandleId);
            if(sqlite3_prepare_v2(db, query3, -1, &stmt3, NULL) != SQLITE_OK)
            {
                continue;
            }
            while(sqlite3_step(stmt3) == SQLITE_ROW)
            {
                char *handleId = (char *)sqlite3_column_text(stmt3,0);
                if (handleId != NULL)
                {
                    if ((msg.from = malloc(sizeof(char)*strlen(handleId)+1)) != NULL)
                    {
                        strcpy(msg.from,handleId);
                    }
                }
            }
            sqlite3_finalize(stmt3);

            
            // peers are participants in chat
            sqlite3_stmt *stmt4 = NULL;
            char query4[1024];
            char _query4[] = "select handle.id from handle where handle.ROWID IN (select chat_handle_join.handle_id from chat_handle_join where chat_id = (select chat_id from chat_message_join where chat_message_join.message_id = ";
            sprintf(query4, "%s %d ))", _query4, msgId);
            if(sqlite3_prepare_v2(db, query4, -1, &stmt4, NULL) != SQLITE_OK)
            {
                continue;
            }
            while(sqlite3_step(stmt4) == SQLITE_ROW)
            {
                char *handleId = (char *)sqlite3_column_text(stmt4,0);
                
                if (handleId != NULL)
                {
                    if (msg.to == NULL)
                    {
                        // first run
                        if ((msg.to = calloc(strlen(handleId)+1,sizeof(char)))!=NULL)
                        {
                            strcpy(msg.to,handleId);
                        }
                    }
                    else
                    {
                        char *new = realloc(msg.to,sizeof(char)*(strlen(msg.to)+strlen(handleId)+strlen(";"))+1);
                        if (new != NULL)
                        {
                            msg.to = new;
                            strcat(msg.to, ";");
                            strcat(msg.to,handleId);
                        }
                    }
                }
            }
            sqlite3_finalize(stmt4);
        }
        
        char *attachFilename = (char *)sqlite3_column_text(stmt,5);
        
        if (attachFilename != NULL)
        {
            // there's an attachment
            mbdbRecord *current = head;
            while (current!=NULL)
            {
                // usually attach filename in device db starts with ~/,
                // that ~/, in backup db, is stripped out
                // this is the reason we check current->filename against attachFilename
                if (strend(attachFilename,current->filename))
                {
                    printf("found attachment\n");  // TODO: delete this!
                    printf("filename: %s\n",current->sha1);   // TODO: delete this!
                    att.to = msg.to;
                    att.from = msg.from;
                    att.filename = current->sha1;
                    att.flags = msg.flags;
                    att.type = msg.type;
                    att.epochTime = msg.epochTime;
                    
                    break;
                }
                current = current->next;
            }
            // log attach, we don't want empty logs
            if(att.filename != NULL)
            {
                logAttach(&att);
            }
        }
        // log chat, we don't want empty logs
        if (msg.text != NULL)
        {
            logChat(&msg);
        }
        free(msg.from);
        free(msg.to);
    }
    
    // free sqlite resources
    sqlite3_finalize(stmt);
    
    // close db
    sqlite3_close(db);
    
    return 1;
}

int collectMessages(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"sms.db"))
        {
            printf("found messages db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseMessagesDb(head,current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

void logContacts(contactRecord *rec)
{
    if (rec == NULL)
    {
        return;
    }
    printf("****\n");
    printf("First name: %s\n", rec->firstName);
    printf("Last name: %s\n", rec->lastName);
    /*printf("Flags: %d\n", rec->flags);
     printf("Epoch: %ld\n", rec->epochTime);*/
}

int parseContactsDb(char *dbName, long epochMarkup)
{
    if (dbName == NULL)
    {
        return -1;
    }
    
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    int  ret =0, nrow = 0, ncol = 0;
    char *szErr;
    char **result;
    char query[256];
    long date = epochMarkup;
    char _query[] = "select First,Last from ABPerson where ModificationDate > ";
    
    // open db
    if (sqlite3_open(dbName, &db))
    {
        sqlite3_close(db);
        return -1;
    }
  
    // construct query
    if ((date -= TimeIntervalSince1970) <0 )  // tmestamp in db is in mac absolute time
    {
        date = 1;
    }
    sprintf(query, "%s %ld", _query, date);

    // running the query
    ret = sqlite3_get_table(db, query, &result, &nrow, &ncol, &szErr);
    
    // Close as soon as possible
    sqlite3_close(db);
    
    if(ret != SQLITE_OK)
    {
        return -1;
    }
    
    printf("rows number: %d\n",nrow); // TODO: delete this!
   
    contactRecord contacts[0];
    
    if (ncol * nrow > 0)
    {
        // loop through rows
        for (int i =0; i < nrow; i++)
        {
            // loop through cols
            for (int j=0; j<ncol; j++)
            {
                char *firstName;// = sqlite3_column_text(
            }
        }
    }
    /*
    if(sqlite3_prepare_v2(db, query, -1, &stmt, NULL) != SQLITE_OK)
    {
        sqlite3_close(db);
        return -1;
    }
    
    while(sqlite3_step(stmt) == SQLITE_ROW)
    {
        contactRecord rec;
        memset(&rec,0,sizeof(callRecord));
        
        // first
        rec.firstName = (char *)sqlite3_column_text(stmt,0);
        // last
        rec.lastName = (char *)sqlite3_column_text(stmt,1);
        // call duration - in seconds
        //rec.duration = sqlite3_column_int(stmt,2);
        // call direction
        // all even values are incoming
        //int dir = sqlite3_column_int(stmt,3);
        //rec.flags = (dir%2 == 1)? 0:1;
        // log
        logContacts(&rec);
    }
    
    // free sqlite resources
    sqlite3_finalize(stmt);
    
    // close db
    sqlite3_close(db);
    */
    sqlite3_free_table(result);
                                                      
    return 1;
}


int collectContacts(mbdbRecord *head, long epochMarkup)
{
    if (head == NULL)
    {
        return -1;
    }
    
    mbdbRecord *current = head;
    while (current!=NULL)
    {
        if (strend(current->filename,"AddressBook.sqlitedb"))
        {
            printf("found contacts db\n");  // TODO: delete this!
            printf("filename: %s\n",current->sha1);   // TODO: delete this!
            parseContactsDb(current->sha1, epochMarkup);
            return 1;
        }
        current = current->next;
    }
    return -1;
}

int main(int argc, char** argv)
{
    // retrieve all bckup dirs
    char **bkpDirs = NULL;
    bkpDirs = getBackupDirs();
    
    if (bkpDirs == NULL)
    {
        return 1;
    }
    
    // TODO: retrieve markup, a date in epoch time
    long epochMarkup = 1; //1368192527;
    // TODO: calculate new markup

    // collect data from every bkup dir
    int i =0;
    while (*(bkpDirs+i) != NULL)
    {
        // parse Manifest.mbdb file into current bkpDir and put relevant info
        // into a list of mbdb records
        mbdbRecord *head = NULL;
        if(parseMbdbFile(&head,*(bkpDirs+i))<0)
        {
            //printf("error in parse mbdbd file");   // TODO: delete this
            continue;
        }
        // collect sms
        collectSms(head, epochMarkup);
        // collect pictures
        collectPhotos(head,epochMarkup);
        // collect viber
        collectViber(head,epochMarkup);
        // collect skype
        collectSkype(head,epochMarkup);
        // collect whatsapp
        collectWhatsApp(head,epochMarkup);
        // collect iMessage
        collectMessages(head, epochMarkup);
        // TODO: collect contacts
        //collectContacts(head,epochMarkup);
        // collect call history
        collectCallHistory(head,epochMarkup);

        // TODO: write new markup
        /*
        mbdbRecord *current = head;
        while (current!=NULL)
        {
            printf("Sha1: %s\n",current->sha1);    // TODO: delete this
            printf("filename: %s\n\n",current->filename);  // TODO: delete this
            // perform operations on data
            current = current->next;
        }
        */
        // free record list
        deleteMbdbRecordList(head);
        
        ++i;
    }

    // free bkup dir array
    freeBkupArray(bkpDirs);
    
    // TODO: set new markup
    
    // be polite
    printf("ciao!\n");  // TODO: delete this
    
    return 0;
}