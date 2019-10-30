//
//  Copyright © 2018-2019 PSPDFKit GmbH. All rights reserved.
//
//  THIS SOURCE CODE AND ANY ACCOMPANYING DOCUMENTATION ARE PROTECTED BY INTERNATIONAL COPYRIGHT LAW
//  AND MAY NOT BE RESOLD OR REDISTRIBUTED. USAGE IS BOUND TO THE PSPDFKIT LICENSE AGREEMENT.
//  UNAUTHORIZED REPRODUCTION OR DISTRIBUTION IS SUBJECT TO CIVIL AND CRIMINAL PENALTIES.
//  This notice may not be removed from this file.
//

#import "RCTPSPDFKitView.h"
#import <React/RCTUtils.h>
#import "RCTConvert+PSPDFAnnotation.h"
#import "RCTConvert+PSPDFViewMode.h"
#import "RCTConvert+UIBarButtonItem.h"

#define VALIDATE_DOCUMENT(document, ...) { if (!document.isValid) { NSLog(@"Document is invalid."); return __VA_ARGS__; }}

@interface RCTPSPDFKitView ()<PSPDFDocumentDelegate, PSPDFViewControllerDelegate, PSPDFFlexibleToolbarContainerDelegate>

@property (nonatomic, nullable) UIViewController *topController;

@end

@implementation RCTPSPDFKitView

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _pdfController = [[PSPDFViewController alloc] init];
    _pdfController.delegate = self;
    _pdfController.annotationToolbarController.delegate = self;
    _closeButton = [[UIBarButtonItem alloc] initWithImage:[PSPDFKit imageNamed:@"x"] style:UIBarButtonItemStylePlain target:self action:@selector(closeButtonPressed:)];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(annotationChangedNotification:) name:PSPDFAnnotationChangedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(annotationChangedNotification:) name:PSPDFAnnotationsAddedNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(annotationChangedNotification:) name:PSPDFAnnotationsRemovedNotification object:nil];
  }

  return self;
}

- (void)dealloc {
  [self destroyViewControllerRelationship];
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)didMoveToWindow {
  UIViewController *controller = self.pspdf_parentViewController;
  if (controller == nil || self.window == nil || self.topController != nil) {
    return;
  }

  if (self.pdfController.configuration.useParentNavigationBar || self.hideNavigationBar) {
    self.topController = self.pdfController;

  } else {
    self.topController = [[PSPDFNavigationController alloc] initWithRootViewController:self.pdfController];;
  }

  UIView *topControllerView = self.topController.view;
  topControllerView.translatesAutoresizingMaskIntoConstraints = NO;

  [self addSubview:topControllerView];
  [controller addChildViewController:self.topController];
  [self.topController didMoveToParentViewController:controller];

  [NSLayoutConstraint activateConstraints:
   @[[topControllerView.topAnchor constraintEqualToAnchor:self.topAnchor],
     [topControllerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
     [topControllerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
     [topControllerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
     ]];
}

- (void)destroyViewControllerRelationship {
  if (self.topController.parentViewController) {
    [self.topController willMoveToParentViewController:nil];
    [self.topController removeFromParentViewController];
  }
}

- (void)closeButtonPressed:(nullable id)sender {
  if (self.onCloseButtonPressed) {
    self.onCloseButtonPressed(@{});

  } else {
    // try to be smart and pop if we are not displayed modally.
    BOOL shouldDismiss = YES;
    if (self.pdfController.navigationController) {
      UIViewController *topViewController = self.pdfController.navigationController.topViewController;
      UIViewController *parentViewController = self.pdfController.parentViewController;
      if ((topViewController == self.pdfController || topViewController == parentViewController) && self.pdfController.navigationController.viewControllers.count > 1) {
        [self.pdfController.navigationController popViewControllerAnimated:YES];
        shouldDismiss = NO;
      }
    }
    if (shouldDismiss) {
      [self.pdfController dismissViewControllerAnimated:YES completion:NULL];
    }
  }
}

- (UIViewController *)pspdf_parentViewController {
  UIResponder *parentResponder = self;
  while ((parentResponder = parentResponder.nextResponder)) {
    if ([parentResponder isKindOfClass:UIViewController.class]) {
      return (UIViewController *)parentResponder;
    }
  }
  return nil;
}

- (BOOL)enterAnnotationCreationMode {
  [self.pdfController setViewMode:PSPDFViewModeDocument animated:YES];
  [self.pdfController.annotationToolbarController updateHostView:nil container:nil viewController:self.pdfController];
  return [self.pdfController.annotationToolbarController showToolbarAnimated:YES];
}

- (BOOL)exitCurrentlyActiveMode {
  return [self.pdfController.annotationToolbarController hideToolbarAnimated:YES];
}

- (BOOL)saveCurrentDocument {
  return [self.pdfController.document saveWithOptions:nil error:NULL];
}

#pragma mark - PSPDFDocumentDelegate

- (void)pdfDocumentDidSave:(nonnull PSPDFDocument *)document {
  if (self.onDocumentSaved) {
    self.onDocumentSaved(@{});
  }
}

- (void)pdfDocument:(PSPDFDocument *)document saveDidFailWithError:(NSError *)error {
  if (self.onDocumentSaveFailed) {
    self.onDocumentSaveFailed(@{@"error": error.description});
  }
}

#pragma mark - PSPDFViewControllerDelegate

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController didTapOnAnnotation:(PSPDFAnnotation *)annotation annotationPoint:(CGPoint)annotationPoint annotationView:(UIView<PSPDFAnnotationPresenting> *)annotationView pageView:(PSPDFPageView *)pageView viewPoint:(CGPoint)viewPoint {
  if (self.onAnnotationTapped) {
    NSData *annotationData = [annotation generateInstantJSONWithError:NULL];
    NSDictionary *annotationDictionary = [NSJSONSerialization JSONObjectWithData:annotationData options:kNilOptions error:NULL];

    self.onAnnotationTapped(annotationDictionary);
  }
  return self.disableDefaultActionForTappedAnnotations;
}

- (BOOL)pdfViewController:(PSPDFViewController *)pdfController shouldSaveDocument:(nonnull PSPDFDocument *)document withOptions:(NSDictionary<PSPDFDocumentSaveOption,id> *__autoreleasing  _Nonnull * _Nonnull)options {
  return !self.disableAutomaticSaving;
}

- (void)pdfViewController:(PSPDFViewController *)pdfController didConfigurePageView:(PSPDFPageView *)pageView forPageAtIndex:(NSInteger)pageIndex {
  [self onStateChangedForPDFViewController:pdfController pageView:pageView pageAtIndex:pageIndex];
}

- (void)pdfViewController:(PSPDFViewController *)pdfController willBeginDisplayingPageView:(PSPDFPageView *)pageView forPageAtIndex:(NSInteger)pageIndex {
  [self onStateChangedForPDFViewController:pdfController pageView:pageView pageAtIndex:pageIndex];
}

#pragma mark - PSPDFFlexibleToolbarContainerDelegate

- (void)flexibleToolbarContainerDidShow:(PSPDFFlexibleToolbarContainer *)container {
  PSPDFPageIndex pageIndex = self.pdfController.pageIndex;
  PSPDFPageView *pageView = [self.pdfController pageViewForPageAtIndex:pageIndex];
  [self onStateChangedForPDFViewController:self.pdfController pageView:pageView pageAtIndex:pageIndex];
}

- (void)flexibleToolbarContainerDidHide:(PSPDFFlexibleToolbarContainer *)container {
  PSPDFPageIndex pageIndex = self.pdfController.pageIndex;
  PSPDFPageView *pageView = [self.pdfController pageViewForPageAtIndex:pageIndex];
  [self onStateChangedForPDFViewController:self.pdfController pageView:pageView pageAtIndex:pageIndex];
}

#pragma mark - Instant JSON

- (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)getAnnotations:(PSPDFPageIndex)pageIndex type:(PSPDFAnnotationType)type {
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, nil);

  NSArray <PSPDFAnnotation *> *annotations = [document annotationsForPageAtIndex:pageIndex type:type];
  NSArray <NSDictionary *> *annotationsJSON = [RCTConvert instantJSONFromAnnotations:annotations];
  return @{@"annotations" : annotationsJSON};
}

- (BOOL)addReplyForAnnotationWithUUID:(NSString *)annotationUUID contents:(NSString *)contents
  {
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, NO)
  BOOL success = NO;

  // Get the annotation you want to add the reply to
  PSPDFAnnotation *annotation;
  NSArray<PSPDFAnnotation *> *allAnnotations = [[document allAnnotationsOfType:PSPDFAnnotationTypeAll].allValues valueForKeyPath:@"@unionOfArrays.self"];
  for (PSPDFAnnotation *annot in allAnnotations) {
    if ([annot.uuid isEqualToString:annotationUUID]) {
      annotation = annot;
      break;
    }
  }

  // Add the reply.
  if (annotation) {
    PSPDFNoteAnnotation *reply = [[PSPDFNoteAnnotation alloc] initWithContents:contents];
    reply.color = annotation.color;
    reply.inReplyToAnnotation = annotation;
    reply.flags |= ~PSPDFAnnotationFlagReadOnly;
    success = [document addAnnotations:@[reply] options:nil];
  }

  if (!success) {
    NSLog(@"Failed to add reply.");
  }

  return success;
}

- (BOOL)addReplyWithUUID:(NSString *)annotationUUID contents:(id)contents {
  NSData *data;
  if ([contents isKindOfClass:NSString.class]) {
    data = [contents dataUsingEncoding:NSUTF8StringEncoding];
  } else if ([contents isKindOfClass:NSDictionary.class])  {
    data = [NSJSONSerialization dataWithJSONObject:contents options:0 error:nil];
  } else {
    NSLog(@"Invalid JSON Annotation.");
    return NO;
  }
  
  id jsonReply = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, NO)
  BOOL success = NO;
  PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;

  // Get the annotation you want to add the reply to
  PSPDFAnnotation *annotation;
  NSArray<PSPDFAnnotation *> *allAnnotations = [[document allAnnotationsOfType:PSPDFAnnotationTypeAll].allValues valueForKeyPath:@"@unionOfArrays.self"];
  for (PSPDFAnnotation *annot in allAnnotations) {
    if ([annot.name isEqualToString:annotationUUID]) {
      annotation = annot;
      break;
    }
  }

  // Add the reply.
  if (annotation) {
    PSPDFNoteAnnotation *reply = [[PSPDFNoteAnnotation alloc] initWithContents:jsonReply[@"text"]];
    PSPDFAnnotation *tempReply = [PSPDFAnnotation annotationFromInstantJSON:data documentProvider:documentProvider error:NULL];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    NSDate *createdAt = [dateFormatter dateFromString:jsonReply[@"createdAt"]];
    NSDate *lastModified = [dateFormatter dateFromString:jsonReply[@"updatedAt"]];
    
    // PSPDFAnnotationFlags lockedFlags = PSPDFAnnotationFlagLocked;
    
    // Avances readOnly (solo no deja editar)
    NSArray *replyFlags = jsonReply[@"customFlags"];
    // NSArray *replyFlags = jsonReply[@"flags"];
    NSString *flagsString = [[replyFlags valueForKey:@"description"] componentsJoinedByString:@""];
    if([flagsString containsString:@"readOnly"]){
      // reply.editable = false;
      reply.flags |= ~PSPDFAnnotationFlagReadOnly;
    };
    
    reply.creationDate = createdAt;
    reply.inReplyToAnnotation = annotation;
    reply.iconName = jsonReply[@"icon"];
    reply.pageIndex = annotation.absolutePageIndex;
    reply.user = jsonReply[@"creatorName"];
    reply.name = jsonReply[@"name"];
    reply.lastModified = lastModified;
    success = [document addAnnotations:@[reply] options:nil];
  }

  if (!success) {
    NSLog(@"Failed to add reply.");
  }

  return success;
}

- (BOOL)addAnnotation:(id)jsonAnnotation {
  NSData *data;
  printf("annotation2");
  if ([jsonAnnotation isKindOfClass:NSString.class]) {
    data = [jsonAnnotation dataUsingEncoding:NSUTF8StringEncoding];
  } else if ([jsonAnnotation isKindOfClass:NSDictionary.class])  {
    data = [NSJSONSerialization dataWithJSONObject:jsonAnnotation options:0 error:nil];
  } else {
    NSLog(@"Invalid JSON Annotation.");
    return NO;
  }
  
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, NO)
  PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;

  BOOL success = NO;
  if (data) {
    PSPDFAnnotation *annotation = [PSPDFAnnotation annotationFromInstantJSON:data documentProvider:documentProvider error:NULL];

    id jsonReply = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *replyFlags = jsonReply[@"customFlags"];
    NSString *flagsString = [[replyFlags valueForKey:@"description"] componentsJoinedByString:@""];
    if([flagsString containsString:@"readOnly"]){
      annotation.flags = -64;
      //annotation.hidden = false;
    }
    success = [document addAnnotations:@[annotation] options:nil];
    
    NSArray<PSPDFAnnotation *> *allAnnotations2 = [[document allAnnotationsOfType:PSPDFAnnotationTypeAll].allValues valueForKeyPath:@"@unionOfArrays.self"];
    for (PSPDFAnnotation *annot2 in allAnnotations2) {
      if ([annot2.name isEqualToString:annotation.name]) {
        NSLog(@"flags: %i", annotation.flags);
        break;
      }
    }
  }

  if (!success) {
    NSLog(@"Failed to add annotation.");
  }

  return success;
}

- (BOOL)removeAnnotationWithUUID:(NSString *)annotationUUID {
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, NO)
  BOOL success = NO;

  NSArray<PSPDFAnnotation *> *allAnnotations = [[document allAnnotationsOfType:PSPDFAnnotationTypeAll].allValues valueForKeyPath:@"@unionOfArrays.self"];
  for (PSPDFAnnotation *annotation in allAnnotations) {
    // Remove the annotation if the uuids match.
    if ([annotation.uuid isEqualToString:annotationUUID]) {
      success = [document removeAnnotations:@[annotation] options:nil];
      break;
    }
  }
  
  if (!success) {
    NSLog(@"Failed to remove annotation.");
  }
  return success;
}

- (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)getAllUnsavedAnnotations {
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, nil)

  PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;
  NSData *data = [document generateInstantJSONFromDocumentProvider:documentProvider error:NULL];
  NSDictionary *annotationsJSON = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
  return annotationsJSON;
}

- (BOOL)addAnnotations:(id)jsonAnnotations {
  NSData *data;
  printf("annotation 1");
  if ([jsonAnnotations isKindOfClass:NSString.class]) {
    data = [jsonAnnotations dataUsingEncoding:NSUTF8StringEncoding];
  } else if ([jsonAnnotations isKindOfClass:NSDictionary.class])  {
    data = [NSJSONSerialization dataWithJSONObject:jsonAnnotations options:0 error:nil];
  } else {
    NSLog(@"Invalid JSON Annotations.");
    return NO;
  }
  
  PSPDFDataContainerProvider *dataContainerProvider = [[PSPDFDataContainerProvider alloc] initWithData:data];
  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, NO)
  PSPDFDocumentProvider *documentProvider = document.documentProviders.firstObject;
  BOOL success = [document applyInstantJSONFromDataProvider:dataContainerProvider toDocumentProvider:documentProvider lenient:NO error:NULL];
  if (!success) {
    NSLog(@"Failed to add annotations.");
  }

  [self.pdfController reloadPageAtIndex:self.pdfController.pageIndex animated:NO];
  return success;
}

#pragma mark - Forms

- (NSDictionary<NSString *, id> *)getFormFieldValue:(NSString *)fullyQualifiedName {
  if (fullyQualifiedName.length == 0) {
    NSLog(@"Invalid fully qualified name.");
    return nil;
  }

  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document, nil)
  
  for (PSPDFFormElement *formElement in document.formParser.forms) {
    if ([formElement.fullyQualifiedFieldName isEqualToString:fullyQualifiedName]) {
      id formFieldValue = formElement.value;
      return @{@"value": formFieldValue ?: [NSNull new]};
    }
  }

  return @{@"error": @"Failed to get the form field value."};
}

- (void)setFormFieldValue:(NSString *)value fullyQualifiedName:(NSString *)fullyQualifiedName {
  if (fullyQualifiedName.length == 0) {
    NSLog(@"Invalid fully qualified name.");
    return;
  }

  PSPDFDocument *document = self.pdfController.document;
  VALIDATE_DOCUMENT(document)

  for (PSPDFFormElement *formElement in document.formParser.forms) {
    if ([formElement.fullyQualifiedFieldName isEqualToString:fullyQualifiedName]) {
      if ([formElement isKindOfClass:PSPDFButtonFormElement.class]) {
        if ([value isEqualToString:@"selected"]) {
          [(PSPDFButtonFormElement *)formElement select];
        } else if ([value isEqualToString:@"deselected"]) {
          [(PSPDFButtonFormElement *)formElement deselect];
        }
      } else if ([formElement isKindOfClass:PSPDFChoiceFormElement.class]) {
        ((PSPDFChoiceFormElement *)formElement).selectedIndices = [NSIndexSet indexSetWithIndex:value.integerValue];
      } else if ([formElement isKindOfClass:PSPDFTextFieldFormElement.class]) {
        formElement.contents = value;
      } else if ([formElement isKindOfClass:PSPDFSignatureFormElement.class]) {
        NSLog(@"Signature form elements are not supported.");
      } else {
        NSLog(@"Unsupported form element.");
      }
      break;
    }
  }
}

#pragma mark - Notifications

- (void)annotationChangedNotification:(NSNotification *)notification {
  id object = notification.object;
  NSArray <PSPDFAnnotation *> *annotations;
  NSArray <PSPDFNoteAnnotation *> *noteAnnotations;
  if ([object isKindOfClass:NSArray.class]) {
    annotations = object;
    noteAnnotations = object;
  } else if ([object isKindOfClass:PSPDFAnnotation.class]) {
    annotations = @[object];
    if([object isKindOfClass:PSPDFNoteAnnotation.class]) {
      noteAnnotations = @[object];
    }
  } else {
    if (self.onAnnotationsChanged) {
      self.onAnnotationsChanged(@{@"error" : @"Invalid annotation error."});
    }
    return;
  }

  NSString *name = notification.name;
  NSString *change;
  if ([name isEqualToString:PSPDFAnnotationChangedNotification]) {
    change = @"changed";
  } else if ([name isEqualToString:PSPDFAnnotationsAddedNotification]) {
    change = @"added";
  } else if ([name isEqualToString:PSPDFAnnotationsRemovedNotification]) {
    change = @"removed";
  }

  NSArray <NSDictionary *> *annotationsJSON = [RCTConvert instantJSONFromAnnotations:annotations];
  NSMutableArray<PSPDFAnnotation *> *inReplyToAnnotation = [NSMutableArray new];
  PSPDFAnnotationAuthorStateModel *authorStateModel;
  PSPDFAnnotationAuthorStateModel *authorState;
  for (PSPDFAnnotation *annotation in annotations) {
    if (annotation.inReplyToAnnotation) {
      [inReplyToAnnotation addObject:annotation.inReplyToAnnotation];
    }
  }

  for (PSPDFNoteAnnotation *noteAnnotation in noteAnnotations) {
    // NSLog(@"authorState %lu",noteAnnotation.type);
    // if([noteAnnotation.type isEqualToNumber:PSPDFAnnotationTypeNote]);
    // if(noteAnnotation.authorStateModel) {
    //   authorStateModel = noteAnnotation.authorStateModel;
    // }
    // if(noteAnnotation.authorState) {
    //   authorState = noteAnnotation.authorState;
    // }
  }

  if (self.onAnnotationsChanged && inReplyToAnnotation.count) {
    self.onAnnotationsChanged(@{@"change" : change,
      @"annotations" : annotationsJSON,
      @"inReplyToAnnotations": [RCTConvert instantJSONFromAnnotations:inReplyToAnnotation]});
  } else if (self.onAnnotationsChanged) {
    self.onAnnotationsChanged(@{@"change" : change, @"annotations" : annotationsJSON});
  }
}

#pragma mark - Customize the Toolbar

- (void)setLeftBarButtonItems:(nullable NSArray <NSString *> *)items forViewMode:(nullable NSString *) viewMode animated:(BOOL)animated {
  NSMutableArray *leftItems = [NSMutableArray array];
  for (NSString *barButtonItemString in items) {
    UIBarButtonItem *barButtonItem = [RCTConvert uiBarButtonItemFrom:barButtonItemString forViewController:self.pdfController];
    if (barButtonItem && ![self.pdfController.navigationItem.rightBarButtonItems containsObject:barButtonItem]) {
      [leftItems addObject:barButtonItem];
    }
  }

  if (viewMode.length) {
    [self.pdfController.navigationItem setLeftBarButtonItems:[leftItems copy] forViewMode:[RCTConvert PSPDFViewMode:viewMode] animated:animated];
  } else {
    [self.pdfController.navigationItem setLeftBarButtonItems:[leftItems copy] animated:animated];
  }
}

- (void)setRightBarButtonItems:(nullable NSArray <NSString *> *)items forViewMode:(nullable NSString *) viewMode animated:(BOOL)animated {
  NSMutableArray *rightItems = [NSMutableArray array];
  for (NSString *barButtonItemString in items) {
    UIBarButtonItem *barButtonItem = [RCTConvert uiBarButtonItemFrom:barButtonItemString forViewController:self.pdfController];
    if (barButtonItem && ![self.pdfController.navigationItem.leftBarButtonItems containsObject:barButtonItem]) {
      [rightItems addObject:barButtonItem];
    }
  }

  if (viewMode.length) {
    [self.pdfController.navigationItem setRightBarButtonItems:[rightItems copy] forViewMode:[RCTConvert PSPDFViewMode:viewMode] animated:animated];
  } else {
    [self.pdfController.navigationItem setRightBarButtonItems:[rightItems copy] animated:animated];
  }
}

- (NSArray <NSString *> *)getLeftBarButtonItemsForViewMode:(NSString *)viewMode {
  NSArray *items;
  if (viewMode.length) {
    items = [self.pdfController.navigationItem leftBarButtonItemsForViewMode:[RCTConvert PSPDFViewMode:viewMode]];
  } else {
    items = [self.pdfController.navigationItem leftBarButtonItems];
  }

  return [self buttonItemsStringFromUIBarButtonItems:items];
}

- (NSArray <NSString *> *)getRightBarButtonItemsForViewMode:(NSString *)viewMode {
  NSArray *items;
  if (viewMode.length) {
    items = [self.pdfController.navigationItem rightBarButtonItemsForViewMode:[RCTConvert PSPDFViewMode:viewMode]];
  } else {
    items = [self.pdfController.navigationItem rightBarButtonItems];
  }

  return [self buttonItemsStringFromUIBarButtonItems:items];
}

#pragma mark - Helpers

- (void)onStateChangedForPDFViewController:(PSPDFViewController *)pdfController pageView:(PSPDFPageView *)pageView pageAtIndex:(NSInteger)pageIndex {
  if (self.onStateChanged) {
    BOOL isDocumentLoaded = [pdfController.document isValid];
    PSPDFPageCount pageCount = pdfController.document.pageCount;
    BOOL isAnnotationToolBarVisible = [pdfController.annotationToolbarController isToolbarVisible];
    BOOL hasSelectedAnnotations = pageView.selectedAnnotations.count > 0;
    BOOL hasSelectedText = pageView.selectionView.selectedText.length > 0;
    BOOL isFormEditingActive = NO;
    for (PSPDFAnnotation *annotation in pageView.selectedAnnotations) {
      if ([annotation isKindOfClass:PSPDFWidgetAnnotation.class]) {
        isFormEditingActive = YES;
        break;
      }
    }

    self.onStateChanged(@{@"documentLoaded" : @(isDocumentLoaded),
                          @"currentPageIndex" : @(pageIndex),
                          @"pageCount" : @(pageCount),
                          @"annotationCreationActive" : @(isAnnotationToolBarVisible),
                          @"annotationEditingActive" : @(hasSelectedAnnotations),
                          @"textSelectionActive" : @(hasSelectedText),
                          @"formEditingActive" : @(isFormEditingActive)
                          });
  }
}

- (NSArray <NSString *> *)buttonItemsStringFromUIBarButtonItems:(NSArray <UIBarButtonItem *> *)barButtonItems {
  NSMutableArray *barButtonItemsString = [NSMutableArray new];
  [barButtonItems enumerateObjectsUsingBlock:^(UIBarButtonItem * _Nonnull barButtonItem, NSUInteger idx, BOOL * _Nonnull stop) {
    NSString *buttonNameString = [RCTConvert stringBarButtonItemFrom:barButtonItem forViewController:self.pdfController];
    if (buttonNameString) {
      [barButtonItemsString addObject:buttonNameString];
    }
  }];
  return [barButtonItemsString copy];
}

@end
